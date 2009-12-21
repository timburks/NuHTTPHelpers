;; source files
(set @m_files     (filelist "^objc/.*.m$"))
(set @c_files     (filelist "^objc/.*.c$"))
(set @nu_files 	  (filelist "^nu/.*nu$"))

(set SYSTEM ((NSString stringWithShellCommand:"uname") chomp))
(case SYSTEM
      ("Darwin"
               (set @cflags "-g -fobjc-gc -DDARWIN -std=gnu99")
               (set @ldflags  "-framework Foundation -framework Nu -lz -lcrypto"))
      ("Linux"
              (set @arch (list "i386"))
              (set gnustep_flags ((NSString stringWithShellCommand:"gnustep-config --objc-flags") chomp))
              (set gnustep_libs ((NSString stringWithShellCommand:"gnustep-config --base-libs") chomp))
              (set @cflags "-g -DLINUX -I/usr/local/include #{gnustep_flags} -std=gnu99")
              (set @ldflags "#{gnustep_libs} -lNu -lz -lcrypto"))
      (else nil))

;; framework description
(set @framework "NuHTTPHelpers")
(set @framework_identifier "nu.programming.nuhttphelpers")
(set @framework_creator_code "????")

(compilation-tasks)
(framework-tasks)

(task "clobber" => "clean" is
      (SH "rm -rf #{@framework_dir}"))

(task "default" => "framework")

(task "doc" is (SH "nudoc"))

