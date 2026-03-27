defmodule Golfex.Clubs.EncryptedBinary do
  use Cloak.Ecto.Binary, vault: Golfex.Vault
end
