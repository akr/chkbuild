require 'build'

def build_ruby(*args)
  Build.target("ruby", *args) {
      |ruby_curr_dir, ruby_version, configure_flags, cflags, ruby_branch|
    Build.cvs(
      ":pserver:anonymous@cvs.ruby-lang.org:/src", "ruby", ruby_branch,
      :cvsweb => "http://www.ruby-lang.org/cgi-bin/cvsweb.cgi"
      )
    Dir.chdir("ruby")
    Build.run("autoconf")
    Build.run("./configure", "--prefix=#{ruby_curr_dir}", "CFLAGS=-Wall -Wformat=2 -Wno-parentheses -g -O2 -DRUBY_GC_STRESS #{cflags}", *configure_flags) {|log|
      if /^checking target system type\.\.\. (\S+)$/ =~ log
        Build.update_title(:version, "ruby-#{ruby_version} #{$1}")
      end
    }
    Build.add_finish_hook {
      log = Build.all_log
      mark = ''
      mark << "[BUG]" if /\[BUG\]/i =~ log
      mark << "[SEGV]" if /segmentation fault|signal segv/i =~
        log.sub(/combination may cause frequent hang or segmentation fault/, '') # skip tk message.
      mark << "[FATAL]" if /\[FATAL\]/i =~ log
      Build.update_title(:mark, mark)
    }
    Build.make
    Build.run("./ruby", "-v") {|log|
      if /^ruby [0-9.]+ \([0-9\-]+\) \[\S+\]$/ =~ log
        Build.update_title(:version, $&)
      end
    }
    Build.make("install")
    Build.run("./ruby", "sample/test.rb", :reason=>"test.rb") {|log|
      Build.update_title(:status) {|val|
        if !val
          if /^end of test/ !~ log
            if /^test: \d+ failed (\d+)/ =~ log
              "#{$1}NotOK"
            else
              "SomethingFail"
            end
          end
        end
      }
    }
    Build.run("./ruby", "test/runner.rb", "-v", :reason=>"test-all") {|log|
      Build.update_title(:status) {|val|
        if !val
          if /^\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors$/ =~ log
            failures = $1.to_i
            errors = $2.to_i
            if failures != 0 || errors != 0
              "#{failures}F#{errors}E"
            end
          else
            "SomethingFail"
          end
        end
      }
    }
  }
end