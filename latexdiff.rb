#!/usr/bin/env ruby

def test_installation_of(command, name = command)
    `#{command} --help`
    unless $?.exitstatus then
        raise "'#{name}' is not installed in the local system, cannot continue."
    end
end

test_installation_of('git latexdiff')
directory = ENV['DIRECTORY'] || ARGV[0] || '.'
method = ENV['METHOD'] || 'CFONTCHBAR'
output = ENV['OUTPUT'] || 'auto-latexdiff.log'
builder = ENV['BUILD_COMMAND'] || 'latexmk'
bibtex = ENV['BIB_TYPE'] || ''
supported_builders = ['latexmk', 'tectonic', 'lualatex', 'xelatex', 'pdflatex']
unless supported_builders.include?(builder) then
    raise "Unknown build command '#{builder}'', expected one of: #{supported_builders}"
end
test_installation_of(builder)

def run_in_directory(directory, command)
    puts "Running '#{command}' in '#{directory}'"
    `
    cd #{directory}
    #{command}
    `
end

latex_roots = Dir["#{directory}/**/*.tex"]
    .map { |name| name.gsub('//', '/') }
    .reject { |file|
        IO.readlines(file).any? { |line|
            begin
                line =~ /^%\s*!\s*[Tt][Ee][Xx]\s*[Rr][Oo]{2}[Tt]\s*=.*$/
            rescue ArgumentError
                puts "Invalid line: #{line}"
                false
            end
        }
    }
puts "The following LaTeX root files were found:"
puts latex_roots

@successful = []
for latex_root in latex_roots
    directory, file = /(.*)\/(.*)$/.match(latex_root).captures
    tags = run_in_directory(directory, 'git show-ref -d --tags | cut -b 42-')
        .split.select{ |it| it.end_with?('^{}')  }
        .map { |it| it.gsub(/^refs\/tags\/(.+)\^\{\}$/, '\1') }
    puts "detected tags #{tags} for file #{latex_root}"
    for tag in tags
        output = "#{directory}/#{file.gsub('.tex', '')}-wrt-#{tag}.pdf"
        puts run_in_directory(
            directory,
            "git latexdiff #{tag}"\
            " --main #{file}"\
            ' --ignore-latex-errors --no-view --latexopt -shell-escape'\
            " -t #{method}"\
            " #{builder}"\
            " -o #{output}"
        )
        if $?.exitstatus == 0 then @successful << file end
    end
end
File.open(output, 'w+') do |file|
    file.puts(@successful)
end
