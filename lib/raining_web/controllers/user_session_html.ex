defmodule RainingWeb.UserSessionHTML do
  use RainingWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:raining, Raining.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
