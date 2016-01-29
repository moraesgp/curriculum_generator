# Curriculum Vitae Generator

## about
Perl script to generate you résumé in diferents languages and formats

## how to
  - Edit the files in the data directory with your details
  - Run the ./run_me.pl script
  - It will create a directory called build that you can upload to some website and then distribute the link

## result
The result is very simple. No bloated html. Just plain html and plain text.

Take a look at my [résumé][gpm] to see the result.

## install dependencies

    sudo cpanm \
    	File::Path \
    	Text::Iconv \
    	File::Copy \
    	Time::Piece

## acknowledgments

I borrowed the html from this website <http://alexking.org/projects/html-resume-template/demo/resume.php>
I hope he doesn't mind!

[gpm]: <http://gabriel.searom.net/>
