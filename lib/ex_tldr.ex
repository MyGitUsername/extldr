defmodule ExTldr do
  @moduledoc """
  Documentation for ExTldr, an Elixir client for tldr-pages.
  """

  # HTTPoison Application.get_env(:ex_tldr, :http_client, HTTPoison)

  @cache_file Enum.join([File.cwd!(), "/cache/cache.txt"])

  @doc """
  Wrapper for the CLI of the ExTldr client. 
  """
  def main(args) do
    args
    |> parse_args
    |> process_os_term
  end

  defp parse_args(args) do
    options = OptionParser.parse(args, switches: [help: :boolean], aliases: [h: :help])

    case options do
      {[help: true], _, _} -> :help
      {_, [], _} -> :help
      {_, os_term, _} -> os_term
    end
  end

  defp print_in_color(output) do
    output
    |> String.replace(~r/(`.*`\n)/, IO.ANSI.green() <> "\\1")
    |> String.replace(~r/(- .*:\n)/, IO.ANSI.yellow() <> "\\1")
    |> IO.puts()
  end

  defp process(:help) do
    IO.puts("""
    ExTldr is an Elixir client for tldr-pages

    Usage:
      - Search command `feh` in the pages of your current operating system:
      `extldr feh`

      - Search Linux command `adduser`:
      `extldr linux adduser`

      - Search a common command, `chroot`, in different operating system:
      `extldr common chroot`

      - Search Linux command `cat`, available in common pages due it is available in different operating systems:
      `extldr linux cat`

    If you have an issue or a suggestion, you can post a new issue on https://github.com/tldr-pages/extldr
    """)
  end

  defp process(os, term), do: describe(os, term)

  defp process_url(os, term) do
    "https://raw.githubusercontent.com/tldr-pages/tldr/master/pages/#{os}/#{term}.md"
  end

  defp process_os_term(:help), do: process(:help)

  defp process_os_term(os_term) when length(os_term) == 1 do
    [os, term] = Enum.join([Os.check_type(), os_term], " ") |> String.split()
    process(os, term)
  end

  defp process_os_term(os_term) when length(os_term) == 2 do
    [os, term] = Enum.join(os_term, " ") |> String.split()
    process(os, term)
  end

  defp insert_cache(tldr, os, term) do
    ExTldr.Cache.put({os, term}, tldr)
    ExTldr.Cache.dump(@cache_file)
  end

  defp fetch_tldr(os, term) do
    case HTTPoison.get(process_url(os, term)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        "Term \"#{term}\" not found on \"#{os}\" pages\nExTldr is looking on \"common\" pages."

        case HTTPoison.get(process_url("common", term)) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            body

          {:ok, %HTTPoison.Response{status_code: 404}} ->
            "Term not found on \"common\" pages."
        end

      {:error, %HTTPoison.Error{reason: reason}} when reason == :nxdomain ->
        raise NoInternetConnectionError

      {:error, %HTTPoison.Error{reason: reason}} when reason != :nxdomain ->
        raise UnexpectedError, reason
    end
  end

  defp describe(os, term) do
    ExTldr.Cache.load(@cache_file)

    case ExTldr.Cache.get({os, term}) do
      nil ->
        tldr = fetch_tldr(os, term)
        print_in_color(tldr)
        insert_cache(tldr, os, term)

      tldr ->
        print_in_color(tldr)
    end
  end
end
