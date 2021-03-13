defmodule App.BankAc do
  def execute(_currenct_state, %App.AddFunds{amount: amount}) when amount < 0 do
    {:error, :amount_must_be_positive}
  end

  def execute(_currenct_state, wish = %App.AddFunds{}) do
    {:ok,
     %App.FundsAdded{
       account_id: wish.account_id,
       amount: wish.amount,
       reply_pid: wish.reply_pid,
       sleep_for: wish.sleep_for
     }}
  end

  def next_state(total, event) do
    send(event.reply_pid, {:building_state, [total, event]})

    case total do
      nil -> event.amount
      total -> total + event.amount
    end
  end
end
