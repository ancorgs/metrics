#! /usr/bin/env ruby
require "open3"
require_relative "lib/db"

def send_data(io, repo_id, metric_id)
  Measurement.where(repo: repo_id, metric: metric_id).order(:date).each do |m|
    io.puts "#{m.date.iso8601} #{m.value}"
  end
  io.puts "e"
end

repos = {
  network: "red",
  bootloader: "green",
  registration: "blue",
  installation: "orange"
}

Open3.pipeline_rw("gnuplot") do |g_stdin, g_stdout, g_wait_thrs|
  g_stdin.print <<'GNUPLOT'
set terminal png size 1024,768
set output "plot.png"

set title "YaST code metrics over time"

# labels for the x axis
set format x "%Y\n%m"

# input
set xdata time
set timefmt x "%Y-%m-%d"
set xrange ["2013-07-31":"2014-11-30"]

set ylabel 'zombies'
# enable the escondary Y axis, autoscaled
set y2range [0:*]
set y2tics
set y2label 'LoC'
GNUPLOT

  g_stdin.print "plot "
  need_comma = false
  repos.each do |repo, color|
    g_stdin.print "," if need_comma
    g_stdin.print "'-' using 1:2 with points lt rgb '#{color}' title 'zombies-1 #{repo}'"
    g_stdin.print ","
    g_stdin.print "'-' using 1:2 axes x1y2 with lines lt rgb '#{color}' title 'loc-1 #{repo}'"
    need_comma = true
  end
  g_stdin.print "\n"

  repos.each do |repo, color|
    repo_id = Repo.find_by_url!("git://github.com/yast/yast-#{repo}.git")
    send_data(g_stdin, repo_id, 2)
    send_data(g_stdin, repo_id, 1)
  end
end
