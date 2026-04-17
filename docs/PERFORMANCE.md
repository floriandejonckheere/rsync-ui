# Performance

This document describes performance optimization tips and best practices.

## Performance Tips

1. **Use database indexes** for foreign keys and common queries
2. **Eager load associations** - use `includes()` to avoid N+1 queries
3. **Cache expensive operations** - use Solid Cache
4. **Optimize images** - compress and serve appropriate sizes
5. **Use Turbo** - reduces full page reloads
6. **Background jobs** - offload heavy processing to Solid Queue
7. **Database connection pooling** - configured in `database.yml`
8. **Asset fingerprinting** - enabled in production via Propshaft
