class RenameMagicLinksToVerificationCodes < ActiveRecord::Migration[8.1]
  def change
    rename_table :magic_links, :verification_codes
  end
end
