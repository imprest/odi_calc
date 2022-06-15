defmodule OdiCalc do
  import Bitwise

  require Record
  Record.defrecordp(:wx, Record.extract(:wx, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wxClose, Record.extract(:wxClose, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wxSize, Record.extract(:wxSize, from_lib: "wx/include/wx.hrl"))
  Record.defrecordp(:wxCommand, Record.extract(:wxCommand, from_lib: "wx/include/wx.hrl"))

  @behaviour :wx_object

  @title "OD Interest Calculator"
  @size {400, 400}
  @btn_file_open 1
  @text_file 2

  @wxHORIZONTAL :wx_const.wxHORIZONTAL()
  @wxVERTICAL :wx_const.wxVERTICAL()
  @wxEXPAND :wx_const.wxEXPAND()
  @wxALL :wx_const.wxALL()
  @wxID_OK :wx_const.wxID_OK()
  @wxID_CANCEL :wx_const.wxID_CANCEL()

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

    panel = :wxPanel.new(frame, [])

    main_sizer = :wxBoxSizer.new(@wxVERTICAL)
    sizer = :wxStaticBoxSizer.new(@wxHORIZONTAL, panel, label: "Input")

    btn_file_open = :wxButton.new(panel, @btn_file_open, label: "Select Bank CSV file: ")
    text_file = :wxTextCtrl.new(panel, @text_file)

    dialogs = [{:wxFileDialog, [panel, []]}]

    label = List.to_atom(:wxButton.getLabel(btn_file_open))
    :wxSizer.add(sizer, btn_file_open, border: 4)
    :wxButton.connect(btn_file_open, :command_button_clicked, userData: label)
    :wxSizer.add(sizer, text_file, flag: @wxEXPAND ||| @wxALL)
    :wxSizer.add(main_sizer, sizer, flag: @wxEXPAND ||| @wxALL)

    :wxPanel.setSizer(panel, main_sizer)

    :wxFrame.show(frame)

    state = %{panel: panel, dialogs: dialogs, file_path: "", text_file: text_file}
    {frame, state}
  end

  def handle_event(wx(event: wxSize(size: size)), state = %{panel: panel}) do
    :wxPanel.setSize(panel, size)
    IO.inspect(state)
    {:noreply, state}
  end

  def handle_event(wx(event: wxClose()), state), do: {:stop, :normal, state}

  def handle_event(
        wx(id: @btn_file_open, event: wxCommand()),
        state = %{panel: panel, text_file: text_file}
      ) do
    dialog = Kernel.apply(:wxFileDialog, :new, [panel, []])

    case :wxFileDialog.showModal(dialog) do
      @wxID_OK ->
        file_path = :wxFileDialog.getPath(dialog)
        :wxTextCtrl.setValue(text_file, file_path)
        {:noreply, %{state | file_path: file_path}}

      @wxID_CANCEL ->
        :cancel
        {:noreply, state}

      any ->
        IO.inspect(any)
        {:noreply, state}
    end
  end
end
