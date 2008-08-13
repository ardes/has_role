module Ardes#:nodoc:
  # Very simple incremental roles - this is where one role implies all 'below', or 'to the left of' it
  #
  # == Example Usage:
  #
  #   class User < ActiveRecord::Base
  #     has_role :admin, :super_admin
  #   end
  #  
  #   u = User.new
  #
  #   u.role = :admin
  #   u.role = :super_admin
  #   u.role = nil
  # 
  # u.role_value will be set in the above to 2, 1, and 0 respectively
  #
  # :role_value is stored on the db
  #
  # You also get predicate methods corresponding to the roles
  #
  #   u.admin?        # performs u.role_value >= 1
  #   u.super_admin?  # performs u.role_value >= 2
  #
  # == Migration
  #
  #   change_table :model do |t|
  #     t.string :role
  #     t.integer :role_value, :default => 0, :null => false
  #   end
  #
  # :role and :role_value always refer to the same role, and this is enforced by the plugin.
  # :role_value is always 'subservient' to the :role attribute, and can't be set directly.
  #
  # The reason both are there is so that
  #   (i) You can make integer comparisons bewteen roles
  #
  #   (ii) You can easily migrate to a new scheme simply by calling the class method update_role_values
  #
  #   For example, if you decided you wanted to add a couple of new roles (in a migration)
  #
  # :role_value is useful when selecting from the db based on role, e.g:
  #
  #   User.find(:all, :conditions => ["role_value >= ?", User.roles[:admin]])
  #
  #   has_scope :admin, :conditions => ["role_value >= ?", User.roles[:admin]]
  #
  # TODO: specs, look into making this an aggregate object
  module HasRole
    def self.included(base)
      class<<base
        def has_role(*roles)
          class_eval do
            cattr_accessor :roles
            roles = roles.last.is_a?(Hash) ? roles.last : roles.inject({}) {|m,r| m.merge(r => m.size + 1)}
            self.roles = HashWithIndifferentAccess.new(roles)
            
            validates_inclusion_of :role, :in => self.roles.keys, :allow_blank => true
            attr_protected :role, :role_value
            before_save :update_role_value_from_role
            
            # predicate methods for each role
            self.roles.each do |role, value|
              module_eval <<-end_eval
                def #{role}?
                  role_value >= #{value} rescue nil
                end
              end_eval
            end
            
            def role_value=(value)
              raise RuntimeError, "You can't set :role_value directly, just set :role"
            end
            
            def role_value
              update_role_value_from_role
            end
            
            def role=(role)
              write_attribute(:role, role.to_s)
            ensure
              update_role_value_from_role
            end
            
            # Use this to migrate all models to a new role scheme
            #
            # For example:
            #
            #   class ChangeRoles < ActiveRecord::Migration
            #     class User < ActiveRecord::Base
            #       has_role :staff, :admin, :payment_admin, :super_admin
            #     end
            #     
            #     def self.up
            #       User.update_role_values
            #     end
            #
            #     # if you need to go down
            #     class DownUser < ActiveRecord::Base
            #       self.table_name = 'users'
            #       has_role :admin, :super_admin
            #     end
            #
            #     def self.down
            #       # first we need to decide what roles :staff and :payment_admin end up as
            #       # in this case we decide that :staff goes away and :payment_admin becomes admin
            #       # This means we cna leave :staff alone and just deal with :payment_admin
            #       User.update_all("role = 'admin'", "role = 'payment_admin'")
            #
            #       # now we use the old scheme
            #       DownUser.update_role_values
            #     end
            #   end
            #
            # (this method simply loads and saves every record, which sets the 'subservient' :role_value 
            #  attribute to the new setting)
            def self.update_role_values
              transaction do
                find(:all).each do |model|
                  model.save(false)
                end
              end
            end
            
          protected
            def update_role_value_from_role
              write_attribute(:role_value, roles[role] || 0)
            end
          end
        end
      end
    end
  end
end