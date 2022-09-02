defmodule OdiCalc do
  import Bitwise
  import :wx_const

  require Record
  Record.defrecordp(:wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wxClose, Record.extract(:wxClose, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wxSize, Record.extract(:wxSize, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wxCommand, Record.extract(:wxCommand, from_lib: "wx/include/wx.hrl"))

  Record.defrecordp(
    :wxFileDirPicker,
    Record.extract(:wxFileDirPicker, from_lib: "wx/include/wx.hrl")
  )

  @behaviour :wx_object

  @title "OD Interest Calculator"
  @size {390, 630}
  @picker_file 1
  @btn_calc 2
  @label_interest 3
  @text_interest 4
  @text_result 5

  @moduledoc """
  Documentation for `OdiCalc`.
  """

  @doc """
  Start OdiCalc gui

  ## Examples

      iex> OdiCalc.start_link()
      {:wx_ref, 35, :wxFrame, _pid}

  """
  def start_link() do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(_args \\ []) do
    wx = :wx.new()
    frame = :wxFrame.new(wx, wxID_ANY(), @title, size: @size)
    :wxFrame.connect(frame, :size)
    :wxFrame.connect(frame, :close_window)

    panel = :wxPanel.new(frame)

    container_sizer = :wxBoxSizer.new(wxVERTICAL())
    main_sizer = :wxBoxSizer.new(wxVERTICAL())
    top_sizer = :wxStaticBoxSizer.new(wxVERTICAL(), panel, label: "Select Bank CSV File:")
    opt_sizer = :wxBoxSizer.new(wxHORIZONTAL())

    file_picker = :wxFilePickerCtrl.new(panel, @picker_file, size: {370, 30})
    :wxFilePickerCtrl.connect(file_picker, :command_filepicker_changed)

    btn_calc = :wxButton.new(panel, @btn_calc, label: "&Calculate OD Interest")
    label = List.to_atom(:wxButton.getLabel(btn_calc))
    :wxButton.connect(btn_calc, :command_button_clicked, userData: label)
    :wxButton.disable(btn_calc)

    label_interest =
      :wxStaticText.new(panel, @label_interest, " &Interest: ",
        style: wxALIGN_CENTER() ||| wxBOTTOM()
      )

    text_interest = :wxTextCtrl.new(panel, @text_interest)
    :wxTextCtrl.setValue(text_interest, "30.00")

    text_result =
      :wxTextCtrl.new(panel, @text_result,
        size: {380, 500},
        style: wxDEFAULT() ||| wxTE_MULTILINE()
      )

    :wxSizer.add(top_sizer, file_picker,
      border: 5,
      flag: wxLEFT() ||| wxRIGHT() ||| wxTOP() ||| wxEXPAND()
    )

    :wxSizer.add(opt_sizer, btn_calc, border: 5, flag: wxRIGHT())
    :wxSizer.add(opt_sizer, label_interest, border: 7, flag: wxTOP())
    :wxSizer.add(opt_sizer, text_interest)
    :wxSizer.add(top_sizer, opt_sizer, border: 5, flag: wxALL())
    :wxSizer.add(main_sizer, top_sizer, flag: wxEXPAND())
    :wxSizer.add(main_sizer, text_result, proportion: 2, border: 5, flag: wxTOP() ||| wxEXPAND())
    :wxSizer.add(container_sizer, main_sizer, border: 5, flag: wxALL() ||| wxEXPAND())

    :wxPanel.setSizerAndFit(panel, container_sizer)
    # :wxFrame.setSizer(frame, container_sizer)
    :wxFrame.layout(frame)
    :wxFrame.center(frame)
    status_bar = :wxFrame.createStatusBar(frame)
    :wxFrame.show(frame)

    state = %{
      panel: panel,
      file_path: "",
      btn_calc: btn_calc,
      text_result: text_result,
      text_interest: text_interest,
      status_bar: status_bar
    }

    {frame, state}
  end

  def handle_event(wx(event: wxSize(size: size)), state = %{panel: panel}) do
    :wxPanel.setSize(panel, size)
    {:noreply, state}
  end

  def handle_event(wx(event: wxClose()), state), do: {:stop, :normal, state}

  def handle_event(
        wx(event: wxFileDirPicker(type: :command_filepicker_changed, path: path)),
        state = %{btn_calc: btn_calc}
      ) do
    if Path.extname(path) === ".csv" do
      :wxButton.enable(btn_calc)
    else
      :wxButton.disable(btn_calc)
    end

    {:noreply, %{state | file_path: path}}
  end

  def handle_event(
        wx(id: @btn_calc, event: wxCommand()),
        state = %{
          text_result: text_result,
          file_path: file_path,
          text_interest: text_interest,
          status_bar: status_bar
        }
      ) do
    interest =
      try do
        List.to_float(:wxTextCtrl.getValue(text_interest))
      rescue
        _ ->
          :wxStatusBar.setStatusText(
            status_bar,
            "Unable to parse interest value. Using default \"30.0\""
          )

          30.0
      end

    bank_dir = Path.dirname(file_path) |> Path.basename()

    cond do
      bank_dir in ["UMB", "ABSA", "ECOBANK"] ->
        case OdiCalc.Calculator.calc(file_path, bank_dir, interest) do
          {:ok, result} ->
            :wxTextCtrl.setValue(text_result, result)
            {:noreply, state}

          err ->
            IO.inspect(err)
            :wxStatusBar.setStatusText(status_bar, "Error occurred.")
            {:noreply, state}
        end

      true ->
        :wxStatusBar.setStatusText(status_bar, "Unknown Bank Dir: #{bank_dir}")
        {:noreply, state}
    end
  end
end
