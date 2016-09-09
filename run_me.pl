#!/usr/bin/perl

use v5.18;
use utf8;
binmode *STDOUT, ":utf8";
use File::Path qw(remove_tree);
use Text::Iconv;
use File::Copy;
use Time::Piece ();

my $langsdir = 'data/langs';
my $companiesdir = 'data/companies';
my $otherstuffdir = 'data/other_stuff';

my $txttemplate;
my $htmltemplate;
my $indextemplate;
my $jobhtmltemplate;
my $txtwidth = 100;

my %txts;
my %htmls;
my %langs;

my $build_time = Time::Piece::localtime->strftime('%F %T');

sub text_cleaner {
	my $converter = Text::Iconv->new('UTF-8', 'ASCII//TRANSLIT');
	chomp(my $clean_text = $converter->convert(+shift));
	$clean_text =~ s/ /-/g;
	lc $clean_text;
}

sub get_companies_block {
	my $lang = shift;
	unless(defined $langs{$lang}->{companies}) {
		return undef;
	}
	my %companies = %{ $langs{$lang}->{companies} };
	my @companies_lines;
	foreach(reverse sort keys %companies) {
		my $mask = sprintf "%%-20s%%s%%%ds", $txtwidth - 20 - length $companies{$_}->{__NAME__};
		my $firstline = sprintf $mask, $companies{$_}->{__PERIOD__}, $companies{$_}->{__NAME__}, $companies{$_}->{__LOCATION__};
		push @companies_lines, $firstline;
		push @companies_lines, sprintf "                    %s", $companies{$_}->{__DESC__};
		push @companies_lines, "";
		my @role = split "\n", $companies{$_}->{__MY_RESPS__};
		push @companies_lines, sprintf "                    %s", $companies{$_}->{__MY_POSITION__};
		push @companies_lines,  map { "                    - $_" } @role;
		push @companies_lines, "";
	}
	join "\n", @companies_lines;
}

sub get_contact_block {
	my $lang = shift;
	my @contact = (
		sprintf($langs{$lang}->{__TEL__} . "%%%ds", $txtwidth - length $langs{$lang}->{__TEL__} ),
		sprintf($langs{$lang}->{__EMAIL__} . "%%%ds", $txtwidth - length $langs{$lang}->{__EMAIL__}),
	);

	my @address = split "\n", $langs{$lang}->{__ADDRESS__};
	push @address, $langs{$lang}->{__COUNTRY__};

	my $counter = 0;
	my $empty_mask = sprintf "%%%ds", $txtwidth;
	my @contact_block;
	while(my $addressline = shift @address) {
		if($contact[$counter]) {
			push @contact_block, sprintf($contact[$counter], $addressline);
		} else {
			push @contact_block, sprintf($empty_mask, $addressline);
		}
		$counter++;
	}

	join "\n", @contact_block;
}

sub load_file {
	my $filepath = shift;
	my %hash;
	open(FILE, '<:utf8', $filepath) or die "Could not open $_: $!\n";
	my $currkey;
	my @curdata;
	while(<FILE>) {
		chomp;
		if(/^__/) {
			# if line starts with __ this is a key
			if($currkey) {
				$hash{$currkey} = join "\n", @curdata;
			}
			$currkey = $_;
			@curdata = ();
			next;
		}
		push @curdata, $_;
	}
	close FILE;
	$hash{$currkey} = join "\n", @curdata;
	\%hash;
}

my $common_data = load_file 'data/common';
my $file_suffix = text_cleaner $common_data->{__NAME__};

opendir my $dir, $langsdir or die "could not open dir $langsdir: $!";
while(readdir $dir) {
	next if(/^\./);
	my $lang = $_;
	my $temp_hash = load_file $langsdir . "/" . $_;
	$temp_hash->{__HTML_LINK__} = "${file_suffix}-${lang}.html";
	$temp_hash->{__TXT_LINK__} = "${file_suffix}-${lang}.txt";
	$langs{$lang} = $temp_hash;
}
close $dir;

$common_data->{__BUILD_TIME__} = $build_time;

# merge all langs with common

foreach my $lang (keys %langs) {
	foreach(keys %$common_data) {
		$langs{$lang}->{$_} = $common_data->{$_};
	}
}

foreach my $lang (keys %langs) {
	my $address = $common_data->{__ADDRESS__};
	$address .= "\n" . $langs{$lang}->{__COUNTRY__};
	$address =~ s/\n/<br \/>/g;
	$langs{$lang}->{__ADDRESS_HTML__} = $address;
}

opendir my $dir, $companiesdir or die "could not open dir $companiesdir: $!";
while(my $lang = readdir $dir) {
	next if($lang =~ /^\./);
	$langs{$lang}->{companies} = ();
	opendir my $otherdir, $companiesdir . "/$lang" or die "could not open subdir of $companiesdir: $!";
	while(my $companyfile = readdir $otherdir) {
		next if($companyfile =~ /^\./);
		my $company_data = load_file(sprintf "%s/%s/%s", $companiesdir, $lang, $companyfile);
		$langs{$lang}->{companies}->{$companyfile} = $company_data;
	}
}
close $dir;

opendir my $dir, $otherstuffdir or die "could not open dir $otherstuffdir: $!";
while(my $lang = readdir $dir) {
	next if($lang =~ /^\./);
	$langs{$lang}->{other_stuff} = load_file(sprintf "%s/%s", $otherstuffdir, $lang);
}
close $dir;

# open templates
{
	local $/ = undef;
	open(FILE, "<:utf8", "index.html.template") or die $!;
	$indextemplate = <FILE>;
	close FILE;
	open(FILE, "<:utf8", "txt.template") or die $!;
	$txttemplate = <FILE>;
	close FILE;
	open(FILE, "<:utf8", "html.template") or die $!;
	$htmltemplate = <FILE>;
	close FILE;
	open(FILE, "<:utf8", "job.html.template") or die $!;
	$jobhtmltemplate = <FILE>;
	close FILE;
}

remove_tree("build", {error => \my $err, keep_root => 1});
if(@$err) {
	print STDERR "Something is not right\n";
	foreach(@$err) {
		my ($file, $msg) = %$_;
		print STDERR "$file: $msg", "\n";
	}
	exit 1;
}

unless(-e "build" and -d "build") {
	unless(mkdir "build", 0775) {
		print STDERR "Could not create dir build: $!", "\n";
		exit 1;
	}
}

opendir my $dir, "static" or die "could not open dir static: $!";
while(readdir $dir) {
	next if(/^\./);
	copy("static/" . $_, "build") or die "Could not copy file $_: $!";
	print "build/$_", "\n";
}
close $dir;


my @html_langs_list;
foreach my $lang(keys %langs) {
	push @html_langs_list, "<a href=\"${file_suffix}-${lang}.html\">$lang</a>";
}
$common_data->{__LANGS_LINKS_LIST__} = join "<br />\n", @html_langs_list;

foreach(keys %$common_data) {
	$indextemplate =~ s/$_/$common_data->{$_}/g;
}

open my $output, ">:utf8", "build/index.html" or die $!;
print $output $indextemplate;
close $output;

foreach my $lang(keys %langs) {
	my $text = $txttemplate;
	foreach(keys %{ $langs{$lang} }) {
		next unless(/^__/);
		$text =~ s/$_/$langs{$lang}->{$_}/g;
	}
	my $cb = get_contact_block $lang;
	$text =~ s/__CONTACT_BLOCK__/$cb/g;
	my $companies = get_companies_block $lang;
	$text =~ s/__COMPANIES__/$companies/g;

	foreach(keys %{ $langs{$lang}->{other_stuff} }) {
		my $templist = join "\n", map { "                    - $_" } split "\n", $langs{$lang}->{other_stuff}->{$_};
		$text =~ s/$_/$templist/g;

	}

	my $txtfilename = "build/${file_suffix}-${lang}.txt";
	open my $output, ">", $txtfilename  or die $!;
	print $output $text;
	close $output;
	print $txtfilename, "\n";
}

foreach my $lang(keys %langs) {
	my $html = $htmltemplate;
	foreach(keys %{ $langs{$lang} }) {
		next unless(/^__/);
		$html =~ s/$_/$langs{$lang}->{$_}/g;
	}
	if(defined $langs{$lang}->{companies}) {
		my @jobs;
		my %companies = %{ $langs{$lang}->{companies} };
		my @companies_lines;
		foreach(reverse sort keys %companies) {
			my $job = $jobhtmltemplate;
			foreach my $key( %{ $companies{$_} }) {
				next unless($key =~ /^__/);
				# $companies{$_}->{__NAME__}
				$job =~ s/$key/$companies{$_}->{$key}/g;
			}
			my $resps = "<li>";
			$resps .= join("</li><li>", split "\n", $companies{$_}->{__MY_RESPS__});
			$resps .= "</li>\n";
			$job =~ s/__RESPS_LIST__/$resps/g;

			push @jobs, $job;
		}
		$html =~ s/__JOBS__/@jobs/g;
	}
	foreach my $key(keys %{ $langs{$lang}->{other_stuff} }) {
		my $html_list = "<li>";
		$html_list .= join "</li><li>", (split "\n", $langs{$lang}->{other_stuff}->{$key});
		$html_list .= "</li>\n";
		$html =~ s/$key/$html_list/g;
	}
	my $htmlfilename = "build/${file_suffix}-${lang}.html";
	open my $output, ">:utf8", $htmlfilename or die $!;
	print $output $html;
	close $output;
	print $htmlfilename, "\n";
}
