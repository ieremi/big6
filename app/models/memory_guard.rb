# Lets a long-running script stop cleanly before the machine runs out of memory.
# Where a container is shared with the web server (Render runs both in one
# 512MB instance), a script that keeps growing gets the whole container killed,
# web server included, and loses its progress with no message.
#
# The guard remembers the process's memory when it is created and, when asked,
# reports whether the process has grown more than a limit past that.
#
#   guard = MemoryGuard.new(growth_limit_mb: 150)
#   items.each { |item| ...; (puts "stopping"; exit 75) if guard.exceeded? }
class MemoryGuard
  # Resident memory of this process in MB, or nil where it can't be read
  # (anywhere without /proc, such as macOS).
  def self.rss_mb
    kb = File.read("/proc/self/status")[/^VmRSS:\s+(\d+)/, 1]
    kb && kb.to_i / 1024
  rescue Errno::ENOENT
    nil
  end

  def initialize(growth_limit_mb:, reader: -> { self.class.rss_mb })
    @growth_limit_mb = growth_limit_mb
    @reader = reader
    @baseline = reader.call
  end

  # Megabytes grown since the guard was created; nil when memory can't be read.
  def growth_mb
    current = @reader.call
    current && @baseline && current - @baseline
  end

  # Whether memory has grown past the limit. Garbage is collected first so
  # memory that is merely waiting to be freed doesn't trip it.
  def exceeded?
    return false unless @baseline

    GC.start
    growth_mb > @growth_limit_mb
  end
end
