# This scripts reports (to STDOUT) and sums the training duration from
# the events within a specified time period.
#
# Usage example:
#
# bundle exec rails runner \
#    data_requests/aggregate_total_training_hours.rb \
#         --start-date 2025-04-01 \
#         --end-date 2026-03-31

class AggregateTotalTrainingHours

  def main
    events = Event.where("events.start >= '#{options.start_date}'").
               where("events.end <= '#{options.end_date}'")

    num_events = 0
    time_sum = 0

    num_skipped = 0
    time_skipped_sum = 0

    events.each do |event|
      if skip_event?(event)
        num_skipped += 1
        time_skipped_sum += (event.end - event.start)
      else
        num_events += 1
        time_sum += (event.end - event.start)
      end
    end

    puts "Total duration: #{hour_minute_time(time_sum)} (#{num_events} events)"
    puts "\nTotal skipped: #{hour_minute_time(time_skipped_sum)} (#{num_skipped} events)"
  end

  def hour_minute_time(seconds)
    hours = (seconds / 3600.0).to_i
    leftover = seconds - hours * 3600
    minutes = (leftover / 60.0).to_i
    "#{hours}h #{minutes}m"
  end

  def option_names
    [:start_date, :end_date]
  end

  def options(**kwargs)
    # Want to supply options either as arguments to this function (console use case),
    # or on command line.
    return @options if @options

    make_options_struct

    if argument_options?(**kwargs)
      process_argument_options(**kwargs)
    else
      OptionParser.new do |opts|
        process_commandline_options(opts)
      end.parse!
    end
    validate_options

    @options
  end

  def make_options_struct
    @options = Struct.new(*option_names).new
  end

  def argument_options?(**kwargs)
    for opt in option_names
      return true if kwargs.fetch(opt, nil)
    end
    false
  end

  def process_argument_options(**kwargs)
    # These "dates" are technically "times" ...
    start_date = kwargs.fetch(:start_date, nil)
    @options.start_date = Time.parse("#{start_date} 00:00:00")
    end_date = kwargs.fetch(:end_date, nil)
    @options.end_date = Time.parse("#{end_date} 23:59:59")
  end

  def process_commandline_options(opts)
    opts.on('-s', '--start-date START_DATE',
            'Start date for report') do |arg|
      @options.start_date = Time.parse("#{arg} 00:00:00")
    end

    opts.on('-e', '--end-date END_DATE',
            'End date for report') do |arg|
      @options.end_date = Time.parse("#{arg} 00:00:00")
    end
  end

  def validate_options
    raise 'Missing start date' unless @options.start_date
    raise 'Missing end date' unless @options.end_date
  end

  def skip_event?(event)
    # Trying to weed out the multi-day events
    # Really, no event should be more than, say, 20 hours
    (event.end - event.start) > 20 * 3600
  end

end

# Only run automatically if called on the command line
AggregateTotalTrainingHours.new.main if $PROGRAM_NAME == __FILE__
