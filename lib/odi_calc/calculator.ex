defmodule OdiCalc.Calculator do
  alias NimbleCSV.RFC4180, as: CSV

  # in perecentage i.e. 21.5
  @interest_rate 21.0
  # UMB or ABSA
  @bank_type "UMB"

  def calc(csv_file, bank_type \\ @bank_type, interest_rate \\ @interest_rate) do
    # parse the file to normalise the data
    data =
      File.read!(csv_file)
      |> CSV.parse_string(skip_headers: true)
      |> Enum.map(fn x ->
        case bank_type do
          "UMB" ->
            [date, _, value_date, debit, credit, balance] = x

            [
              to_date(date),
              to_date(value_date),
              to_float(debit),
              to_float(credit),
              to_float(balance)
            ]

          "ABSA" ->
            [date, value_date, _desc, _customer_ref, _chq, debit, credit, balance] = x

            [d, m, y] =
              date |> String.slice(0, 10) |> String.split("/") |> Enum.map(&String.to_integer(&1))

            [d1, m1, y1] =
              value_date
              |> String.slice(0, 10)
              |> String.split("/")
              |> Enum.map(&String.to_integer(&1))

            [
              Date.new!(y, m, d),
              Date.new!(y1, m1, d1),
              to_float(debit),
              to_float(credit),
              to_float(balance)
            ]

          "ECOBANK" ->
            [date, value_date, _tx_code, _desc, debit, credit, balance] = x

            {deb, cred} =
              case {debit, credit} do
                {debit, _credit} when debit < 0 ->
                  [0.0, :erlang.abs(debit)]

                {_debit, credit} when credit < 0 ->
                  [:erlang.abs(credit), 0.0]

                _ ->
                  {debit, credit}
              end

            [
              to_date(date),
              to_date(value_date),
              to_float(deb),
              to_float(cred),
              to_float(balance)
            ]
        end
      end)

    # Get only the last balances for each day
    balances =
      data
      |> Enum.reverse()
      |> Enum.uniq_by(fn [x, _, _, _, _] -> x end)
      |> Enum.reverse()
      |> Enum.map(fn [d, _, _, _, bal] -> [d, bal] end)

    # Get end of month date to determine month and days in year for interest calculation
    last_date = balances |> Enum.reverse() |> Enum.at(0) |> Enum.at(0)
    month = Map.get(last_date, :month)
    days_in_year = if Date.leap_year?(last_date), do: 366, else: 365

    # Get last month closing balance if you need to create a dummy first day
    last_month_closing_balance =
      balances
      |> Enum.take_while(fn [d, _] -> Map.get(d, :month) != month end)
      |> Enum.reverse()
      |> Enum.at(0)
      |> Enum.at(1)

    # Remove dates not within the current month
    balances = balances |> Enum.filter(fn [d, _bal] -> Map.get(d, :month) == month end)

    # Add a dummy first day of month if the first day of month was holiday
    first_date = Date.beginning_of_month(last_date)
    [[bal_first_date, _] | _] = balances

    balances =
      case Date.compare(first_date, bal_first_date) do
        :eq -> balances
        :lt -> [[first_date, last_month_closing_balance] | balances]
      end

    # Calcualte actual bal and interest per day
    balances =
      balances
      |> add_days()
      |> Enum.map(fn [date, days, bal] ->
        diff = postponed_values(data, date)
        actual = Float.round(bal + diff, 2)

        [
          date,
          days,
          bal,
          actual,
          Float.round(interest_rate / 100 / days_in_year * abs(actual) * days, 2)
        ]
      end)

    # Calculate total interest for the month and generate details as csv lines
    {total_interest, csv_details} =
      for [date, days, bal, actual, interest] <- balances, reduce: {0.0, []} do
        {total, list} ->
          {total + interest,
           [
             "#{Calendar.strftime(date, "%d-%b-%Y")},#{Integer.to_string(days)},#{Float.to_string(bal)},#{Float.to_string(actual)},#{interest_rate},#{Float.to_string(interest)}\n"
             | list
           ]}
      end

    # Spit out the interest and details for the month
    {:ok,
     List.to_string([
       "Month: #{Calendar.strftime(last_date, "%b %Y")}\n",
       "Date,Days,Online Bal,Actual Bal,% p.a.,Interest\n",
       :lists.reverse(csv_details),
       "Total #{bank_type} Interest: ",
       Float.to_string(Float.round(total_interest, 2))
     ])}
  end

  def to_date(date) do
    [d, m, y] =
      if String.contains?(date, ["-", "/"]) do
        if String.contains?(date, "-") do
          String.split(date, "-")
        else
          String.split(date, "/")
        end
      else
        String.split(date, " ")
      end

    if String.length(y) === 4 do
      Date.new!(String.to_integer(y), short_month_to_num(m), String.to_integer(d))
    else
      Date.new!(String.to_integer("20" <> y), short_month_to_num(m), String.to_integer(d))
    end
  end

  def to_float(num) do
    case Float.parse(num) do
      {n, _} -> n
      :error -> 0.00
    end
  end

  def short_month_to_num(m) do
    case String.upcase(m) do
      "JAN" -> 1
      "FEB" -> 2
      "MAR" -> 3
      "APR" -> 4
      "MAY" -> 5
      "JUN" -> 6
      "JUL" -> 7
      "AUG" -> 8
      "SEP" -> 9
      "OCT" -> 10
      "NOV" -> 11
      "DEC" -> 12
    end
  end

  def postponed_values(data, d) do
    range = Date.range(Date.add(d, -5), d)

    for [x, value_date, debit, credit, _] <- data, Enum.member?(range, x), reduce: 0.0 do
      acc ->
        case Date.compare(value_date, d) do
          :gt -> acc + debit - credit
          _ -> acc
        end
    end
  end

  def add_days(balances), do: add_days(balances, [])

  def add_days([], acc), do: Enum.reverse(acc)

  def add_days(balances, acc) do
    [[date, bal] | rest] = balances

    case rest do
      [] ->
        days = Date.diff(Date.end_of_month(date), date) + 1
        add_days(rest, [[date, days, bal] | acc])

      _ ->
        [[next_date, _] | _] = rest
        days = Date.diff(next_date, date)
        add_days(rest, [[date, days, bal] | acc])
    end
  end
end
