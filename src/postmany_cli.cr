require "./postmany"

exit_code = Postmany::Bootstrap::Runner.new.run(ARGV)
exit(exit_code)
