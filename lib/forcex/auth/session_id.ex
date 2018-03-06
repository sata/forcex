defmodule Forcex.Auth.SessionId do
  @moduledoc """
  Auth via a session id
  """

  @behaviour Forcex.Auth

  def login(conf, starting_struct) do
    schema = "http://www.w3.org/2001/XMLSchema"
    schema_instance = "http://www.w3.org/2001/XMLSchema-instance"
    env = "http://schemas.xmlsoap.org/soap/envelope/"

    envelope = """
    <?xml version="1.0" encoding="utf-8" ?>
    <env:Envelope xmlns:xsd="#{schema}" xmlns:xsi="#{schema_instance}" xmlns:env="#{env}">
    <env:Body>
    <n1:login xmlns:n1="urn:partner.soap.sforce.com">
      <n1:username>#{conf.username}</n1:username>
      <n1:password>#{conf.password}#{conf.security_token}</n1:password>
    </n1:login>
    </env:Body>
    </env:Envelope>
    """

    headers = [
      {"Content-Type", "text/xml; charset=UTF-8"},
      {"SOAPAction", "login"}
    ]

    "https://login.salesforce.com/services/Soap/u/#{starting_struct.api_version}"
    |> HTTPoison.post!(envelope, headers)
    |> handle_login_response
  end

  defp handle_login_response(%HTTPoison.Response{body: body, status_code: 200}) do
    {:ok,
     {'{http://schemas.xmlsoap.org/soap/envelope/}Envelope', _,
      [
        {'{http://schemas.xmlsoap.org/soap/envelope/}Body', _,
         [
           {'{urn:partner.soap.sforce.com}loginResponse', _,
            [
              {'{urn:partner.soap.sforce.com}result', _, login_parameters}
            ]}
         ]}
      ]}, _} = :erlsom.simple_form(body)

    server_url = extract_from_parameters(login_parameters, :serverUrl)
    session_id = extract_from_parameters(login_parameters, :sessionId)
    host = server_url |> URI.parse() |> Map.get(:host)
    endpoint = "https://#{host}/"

    %{authorization_header: authorization_header(session_id), endpoint: endpoint}
  end

  defp extract_from_parameters(params, key) do
    compound_key = "{urn:partner.soap.sforce.com}#{key}" |> to_charlist
    {^compound_key, _, [value]} = :lists.keyfind(compound_key, 1, params)
    value |> to_string
  end

  @spec authorization_header(session_id :: String.t()) :: list
  def authorization_header(nil), do: []

  def authorization_header(session_id) do
    [{"Authorization", "Bearer #{session_id}"}]
  end
end