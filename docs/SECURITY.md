# Security

This document describes the security best practices and conventions used in the application.

## Security Best Practices

1. **Always use strong parameters** in controllers
2. **Always authorize actions** with ActionPolicy
3. **Never trust user input** - validate everything
4. **Use prepared statements** - ActiveRecord does this by default
5. **Validate file uploads** - type, size, content
6. **Use HTTPS in production** - configured in Rails
7. **Set CSP headers** - configured in `config/initializers/content_security_policy.rb`
8. **Filter sensitive params** - configured in `config/initializers/filter_parameter_logging.rb`
9. **Keep dependencies updated** - run `bundle update` and `yarn upgrade` regularly
10. **Run Brakeman** - scan for security vulnerabilities before deploys

## Environment Variables

Key environment variables (see `.development.env` for full list):
- `APP_NAME` - Application name (used in database names, module name)
- `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD` - Database connection
- `SECRET_KEY_BASE` - Rails secret (production)

When adding environment variables, update:
- `.development.env`
- `.github/actions/ci.yml`
- `.github/actions/cd.yml`
- `ops/compose.yml`
- `README.md`

## Authorization Pattern (ActionPolicy)

**In Controllers:**
```ruby
class ModelsController < ApplicationController
  # Authorize action before accessing
  def show
    @model = Model.find(params[:id])

    authorize! @model
  end

  # Use authorized_scope for collections
  def index
    @models = authorized_scope(Model.all)
  end
end
```

**In Policies:**
```ruby
class ModelPolicy < ApplicationPolicy
  # Scope queries to current user's records
  relation_scope do |scope|
    scope.where(user:)
  end

  def show?
    # User can view their own models
    record.user_id == user.id
  end

  def update?
    # User can update their own models
    record.user_id == user.id
  end

  def destroy?
    # User can delete their own models
    record.user_id == user.id
  end
end
```

## Scoping to Current User

**In Controllers:**
```ruby
# Instead of Model.find(params[:id])
@model = current_user.models.find(params[:id])

# Instead of Model.all
@models = current_user.models.all
```

**In Policies:**
```ruby
relation_scope do |scope|
  scope.where(user:)
end
```
