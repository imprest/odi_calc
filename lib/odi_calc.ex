defmodule OdiCalc do
  use Bitwise
  @behaviour :wx_object
  @title "OD Interest Calculator"
  @size {400, 400}

  @wxUP 64
  @wxDOWN 128
  @wxLEFT 16
  @wxRIGHT 32
  @wxALL @wxUP ||| @wxDOWN ||| @wxLEFT ||| @wxRIGHT
  @wxGROW 8192
  @wxEXPAND @wxGROW
  @wxVERTICAL 8
  @wxHORIZONTAL 4

  @wxID_OK 5100
  @wxID_CANCEL 5101
  @wxID_APPLY 5102
  @wxID_YES 5103
  @wxID_NO 5104

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
    sizer = :wxStaticBoxSizer.new(@wxVERTICAL, panel, [{:label, "Input"}])

    buttons = [:wxButton.new(panel, 1, [{:label, "Select Bank CSV file"}])]
    dialogs = [{:wxFileDialog, [panel, []]}]

    # Add to sizers
    fun = fn button ->
      label = :wxButton.getLabel(button)
      label = List.to_atom(label)
      :wxSizer.add(sizer, button, [{:border, 4}, {:flag, @wxALL ||| @wxEXPAND}])
      :wxButton.connect(button, :command_button_clicked, [{:userData, label}])
    end

    :wx.foreach(fun, buttons)

    :wxSizer.add(main_sizer, sizer)

    :wxPanel.setSizer(panel, main_sizer)

    :wxFrame.show(frame)

    state = %{panel: panel, dialogs: dialogs}
    {frame, state}
  end

  def handle_event({:wx, _, _, _, {:wxSize, :size, size, _}}, state = %{panel: panel}) do
    :wxPanel.setSize(panel, size)
    {:noreply, state}
  end

  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
    {:stop, :normal, state}
  end

  def handle_event({:wx, _, _, _, {:wxCommand, :command_button_clicked, [], 0, 0}}, state) do
    dialog = Kernel.apply(:wxFileDialog, :new, [state.panel, []])

    case :wxFileDialog.showModal(dialog) do
      @wxID_OK ->
        IO.inspect(:wxFileDialog.getPath(dialog))

      @wxID_CANCEL ->
        :cancel

      any ->
        IO.inspect(any)
    end

    {:noreply, state}
  end
end
