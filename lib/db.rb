require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: './config/plexdb.sqlite', bad_attribute_names: :hash)
