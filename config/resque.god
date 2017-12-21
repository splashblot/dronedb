rails_env   = ENV['RAILS_ENV']
raise "Please specify RAILS_ENV." unless rails_env
rails_root  = ENV['RAILS_ROOT'] || File.expand_path(File.join(File.dirname(__FILE__), '..'))
num_workers_import = rails_env == 'production' ? 10 : 1
num_workers_rest = rails_env == 'production' ? 10 : 1

RESQUE_PROCESSORS = [
  [1, "imports", num_workers_import],
  [2, "exports,users,user_dbs,geocodings,synchronizations,tracker,user_migrations,gears", num_workers_rest]
]

RESQUE_PROCESSORS.each do |resque_id, resque_queues, num_workers|    
  num_workers.times do |num|
    God.watch do |w|
        w.dir      = "#{rails_root}"
        w.name     = "resque-#{resque_id}-#{num}"
        w.group    = "resque-#{resque_id}"
        w.interval = 30.seconds
        w.env      = {"QUEUES"=>resque_queues, "RAILS_ENV"=>rails_env, "BUNDLE_GEMFILE"=>"#{rails_root}/Gemfile"}
        w.start    = "bundle exec rake -f #{rails_root}/Rakefile environment resque:work"
        w.log      = "#{rails_root}/log/resque-#{resque_id}.log"

        # restart if memory gets too high
        #w.transition(:up, :restart) do |on|
        #on.condition(:memory_usage) do |c|
        #    c.above = 350.megabytes
        #    c.times = 2
        #end
        #end

        # determine the state on startup
        w.transition(:init, { true => :up, false => :start }) do |on|
        on.condition(:process_running) do |c|
            c.running = true
        end
        end

        # determine when process has finished starting
        w.transition([:start, :restart], :up) do |on|
        on.condition(:process_running) do |c|
            c.running = true
            c.interval = 5.seconds
        end

        # failsafe
        on.condition(:tries) do |c|
            c.times = 5
            c.transition = :start
            c.interval = 5.seconds
        end
        end

        # start if process is not running
        w.transition(:up, :start) do |on|
        on.condition(:process_running) do |c|
            c.running = false
        end
        end
    end
  end
end