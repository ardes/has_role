module Ardes#:nodoc:
  # very simple incremental roles
  #
  # Usage:
  #
  #   has_role :admin, :super_admin
  #
  # This allows setting .role = :admin|:sumper_admin|nil.
  # :role_value will be set in the db
  #
  # .admin? will do role_value >= (admin value)
  #
  # If the model has a role attirbute in db, then a string will be set as well
  #
  # If you do this, you can migrate to a new scheme simply by changing the model def, when records are saved, their role_value
  # is updated.  So migrating the whole lot means loading and then saving every record.
  #
  # role_value is there so you can select from the db based on role, e.g:
  #
  #   User.find(:all, :conditions => ["role_value >= ?", User.roles[:admin]])
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
            
            self.roles.each do |role, value|
              module_eval <<-end_eval
                def #{role}?
                  role_value >= #{value} rescue nil
                end
              end_eval
            end
            
            def role_value=(value)
              raise RuntimeError, "Set the role_value by setting role"
            end
            
            def role_value
              read_attribute(:role_value).blank? ? update_role_value_from_role : read_attribute(:role_value)
            end
            
            def role=(role)
              role = role.to_s
              write_attribute(:role_value, roles[role])
              attribute_names.include?("role") ? write_attribute(:role, role) : @role = role
            end
            
            def role
              attribute_names.include?("role") ? read_attribute(:role) : @role ||= roles.invert[role_value]
            end
            
            # loads and saves every record, use this when you;ve changed the role scheme to update everything
            def self.migrate_roles
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
