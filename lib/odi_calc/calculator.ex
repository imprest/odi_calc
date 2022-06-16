defmodule OdiCalc.Calculator do
  # in perecentage i.e. 21.5
  @interest_rate 21
  # UMB or ABSA
  @bank_type "UMB"

  def calc(csv_file, bank_type \\ @bank_type, interest_rate \\ @interest_rate) do
    # parse the file to normalise the data
    # File.read!("/home/hvaria/Documents/Accounts/ECOBANK/202203.csv")
    data =
      File.read!(csv_file)
      |> String.split("\n", trim: true)
      |> Enum.map(fn x ->
        if bank_type === "UMB" do
          # UMB
          [date, _, value_date, debit, credit, balance] = String.split(x, ",")

          [
            to_date(date),
            to_date(value_date),
            to_float(debit),
            to_float(credit),
            to_float(balance)
          ]
        else
          # ABSA
          [date, value_date, _desc, _chq, debit, credit, balance] = String.split(x, ",")

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
    IO.inspect(Calendar.strftime(last_date, "%b-%Y"), label: "Month")

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

    # Add days
    balances = balances |> add_days()

    # Calcualte actual bal and interest per day
    balances =
      balances
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

    # Format output as csv for easy copy and pasting
    balances
    |> Enum.map(fn [date, days, bal, actual, interest] ->
      IO.puts(
        Calendar.strftime(date, "%d-%b-%Y") <>
          "," <>
          Integer.to_string(days) <>
          "," <>
          Float.to_string(bal) <>
          "," <> Float.to_string(actual) <> ",#{interest_rate}," <> Float.to_string(interest)
      )
    end)

    # Spit out the interest for the month
    balances
    |> Enum.reduce(0.0, fn [_, _, _, _, i], acc -> acc + i end)
    |> Float.round(2)
    |> IO.inspect(label: "Interest")
  end

  def to_date(date) do
    [d, m, y] = String.split(date, " ")

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

    data
    |> Enum.filter(fn [x, _, _, _, _] -> Enum.member?(range, x) end)
    |> Enum.reduce(0.0, fn [_, value_date, debit, credit, _], acc ->
      case Date.compare(value_date, d) do
        :gt ->
          acc + debit - credit

        _ ->
          acc
      end
    end)
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
