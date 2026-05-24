defmodule ThesisPhoenixLiveviewWeb.PageController do
  use ThesisPhoenixLiveviewWeb, :controller

  def home(conn, _params) do
    text(conn, "Backend is working")
  end
end
