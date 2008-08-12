require 'ardes/has_role'

ActiveRecord::Base.send :include, Ardes::HasRole
