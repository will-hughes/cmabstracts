# EPrints queue configuration to prevent memory issues
$c->{max_queue_processes} = 1;
$c->{queue_jobs_per_child} = 5;

# Queue priorities
$c->{queue_priority} = {
    low => 100,
    medium => 50, 
    high => 1
};

# Optional: Add queue processing delays to reduce load
$c->{queue_delay} = {
    low => 10,     # 10 second delay between low priority jobs
    medium => 5,   # 5 second delay between medium priority jobs  
    high => 0      # No delay for high priority jobs
};

1;
