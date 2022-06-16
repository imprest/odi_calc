defmodule OdiCalc do
  import Bitwise

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
  @size {390, 660}
  @picker_file 1
  @btn_calc 2
  @text_result 3

  @wxVERTICAL :wx_const.wxVERTICAL()
  @wxEXPAND :wx_const.wxEXPAND()
  @wxALL :wx_const.wxALL()
  @wxRIGHT :wx_const.wxRIGHT()
  @wxLEFT :wx_const.wxLEFT()
  @wxTOP :wx_const.wxTOP()
  @wxDEFAULT :wx_const.wxDEFAULT()
  @wxTE_MULTILINE :wx_const.wxTE_MULTILINE()

  # @wxHORIZONTAL :wx_const.wxHORIZONTAL()
  # @wxBOTTOM :wx_const.wxBOTTOM()
  # @wxALIGN_CENTER :wx_const.wxALIGN_CENTER()
  # @wxALIGN_BOTTOM :wx_const.wxALIGN_BOTTOM()
  # @wxID_OK :wx_const.wxID_OK()
  # @wxID_CANCEL :wx_const.wxID_CANCEL()

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
    frame = :wxFrame.new(wx, -1, @title, size: @size)
    :wxFrame.connect(frame, :size)
    :wxFrame.connect(frame, :close_window)

    panel = :wxPanel.new(frame)

    main_sizer = :wxBoxSizer.new(@wxVERTICAL)
    top_sizer = :wxStaticBoxSizer.new(@wxVERTICAL, panel, label: "Select Bank CSV File:")

    file_picker = :wxFilePickerCtrl.new(panel, @picker_file, size: {370, 30})
    :wxFilePickerCtrl.connect(file_picker, :command_filepicker_changed)

    btn_calc = :wxButton.new(panel, @btn_calc, label: "Calculate OD Interest")
    label = List.to_atom(:wxButton.getLabel(btn_calc))
    :wxButton.connect(btn_calc, :command_button_clicked, userData: label)

    text_result =
      :wxTextCtrl.new(panel, @text_result, size: {380, 450}, style: @wxDEFAULT ||| @wxTE_MULTILINE)

    :wxSizer.add(top_sizer, file_picker, border: 5, flag: @wxLEFT ||| @wxRIGHT ||| @wxTOP)
    :wxSizer.add(top_sizer, btn_calc, border: 5, flag: @wxALL)

    :wxSizer.add(main_sizer, top_sizer, flag: @wxRIGHT ||| @wxLEFT, border: 5)

    :wxSizer.add(main_sizer, text_result,
      border: 5,
      proportion: 4,
      flag: @wxTOP ||| @wxLEFT
    )

    :wxSizer.add(main_sizer, 2, 2, proportion: 1, flag: @wxEXPAND)

    :wxFrame.setSizerAndFit(panel, main_sizer)
    :wxFrame.center(frame)
    :wxFrame.createStatusBar(frame)
    :wxFrame.show(frame)

    state = %{panel: panel, file_path: "", text_result: text_result}
    {frame, state}
  end

  def handle_event(wx(event: wxSize(size: size)), state = %{panel: panel}) do
    :wxPanel.setSize(panel, size)
    {:noreply, state}
  end

  def handle_event(wx(event: wxClose()), state), do: {:stop, :normal, state}

  def handle_event(
        wx(event: wxFileDirPicker(type: :command_filepicker_changed, path: path)),
        state
      ) do
    {:noreply, %{state | file_path: path}}
  end

  def handle_event(
        wx(id: @btn_calc, event: wxCommand()),
        state = %{text_result: text_result, file_path: file_path}
      ) do
    case OdiCalc.Calculator.calc(file_path) do
      {:ok, result} ->
        :wxTextCtrl.setValue(text_result, result)
        {:noreply, state}

      _ ->
        # TODO: error occurred, Display an error in statusBar
        {:noreply, state}
    end
  end
end
