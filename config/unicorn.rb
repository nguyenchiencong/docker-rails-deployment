# Sample verbose configuration file for Unicorn (not Rack)
#
# This configuration file documents many features of Unicorn
# that may not be needed for some applications. See
# http://unicorn.bogomips.org/examples/unicorn.conf.minimal.rb
# for a much simpler configuration file.
#
# See http://unicorn.bogomips.org/Unicorn/Configurator.html for complete
# documentation.

# Use at least one worker per core if you're on a dedicated server,
# more will usually help for _short_ waits on databases/caches.
worker_processes 2

# nuke workers after 30 seconds instead of 60 seconds (the default)
timeout 120

# "preload_app true" for memory savings
# http://rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
preload_app true

# http://rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
GC.respond_to?(:copy_on_write_friendly=) and
GC.copy_on_write_friendly = true
  
# Since Unicorn is never exposed to outside clients, it does not need to
# run on the standard HTTP port (80), there is no reason to start Unicorn
# as root unless it's from system init scripts.
# If running the master process as root and the workers as an unprivileged
# user, do this to switch euid/egid in the workers (also chowns logs):
# user "unprivileged_user", "unprivileged_group"

# listen on both a Unix domain socket and a TCP port,
# we use a shorter backlog for quicker failover when busy
# listen "/tmp/unicorn.{{ app_name }}.sock", :backlog => 64
deploy_path = "/usr/src/app"
# listen "#{deploy_path}/tmp/unicorn.sock", :backlog => 64
# listen 8080, :tcp_nopush => true
listen 3000, :tcp_nopush => true

pid_file = "#{deploy_path}/tmp/pids/unicorn.pid"
old_pid_file = "#{pid_file}.oldbin"
log_file = "#{deploy_path}/log/unicorn.log"
err_file = "#{deploy_path}/log/unicorn_error.log"

pid pid_file

# FUTURE: add to outside log
# By default, the Unicorn logger will write to stderr.
# Additionally, ome applications/frameworks log to stderr or stdout,
# so prevent them from going to /dev/null when daemonized here:
stdout_path log_file
stderr_path err_file

# Help ensure your application will always spawn in the symlinked
# "current" directory that Capistrano sets up.
working_directory("#{deploy_path}") 

before_exec do |server|
  ENV['BUNDLE_GEMFILE'] = "#{deploy_path}/Gemfile"
end

before_fork do |server, worker|
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection.disconnect!
    Rails.logger.info('Disconnected from ActiveRecord')
  end

  ##
  # When sent a USR2, Unicorn will suffix its pidfile with .oldbin and
  # immediately start loading up a new version of itself (loaded with a new
  # version of our app). When this new Unicorn is completely loaded
  # it will begin spawning workers. The first worker spawned will check to
  # see if an .oldbin pidfile exists. If so, this means we've just booted up
  # a new Unicorn and need to tell the old one that it can now die. To do so
  # we send it a QUIT.
  #
  # Using this method we get 0 downtime deploys.
 
  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end

  sleep 1
end

after_fork do |server, worker|
  ##
  # Unicorn master loads the app then forks off workers - because of the way
  # Unix forking works, we need to make sure we aren't using any of the parent's
  # sockets, e.g. db connection
 
  # ActiveRecord::Base.establish_connection
  # CHIMNEY is GitHub's internal library. They have not open sourced it yet.
  # CHIMNEY.client.connect_to_server
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
    Rails.logger.info('Connected to ActiveRecord')
  end

  # Redis and Memcached would go here but their connections are established
  # on demand, so the master never opens a socket
  if defined?(Resque)
    Resque.redis.client.reconnect
    Rails.logger.info('Connected to Redis')
  end
end


