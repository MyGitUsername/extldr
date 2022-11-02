defmodule ExTldr.Cache do
  use Nebulex.Cache,
    otp_app: :ex_tldr,
    adapter: Nebulex.Adapters.Local,
    behavior: Nebulex.Adapter.Persistence
end
