use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use Tie::IxHash;
use JSON;
use Data::Dumper;

# Configuration
my $CONFIG = {
    max_file_size => 50 * 1024 * 1024,
    version       => '1.0',
};

# Main function
sub main {
    my $result = {
        status    => 'success',
        timestamp => get_timestamp(),
        message   => '',
        result    => {}
    };

    if (@ARGV != 1) {
        $result->{status} = 'error';
        $result->{message} = 'Usage: perl normalize-wrods.pl <input.xml>';
        print_json($result);
        exit 1;
    }
    
    my $xml_file = $ARGV[0];
    
    unless (-e $xml_file) {
        $result->{status} = 'error';
        $result->{message} = "XML file '$xml_file' not found";
        print_json($result);
        exit 1;
    }
    
    eval {
        my $xml_content = read_xml_file($xml_file);
        my $word_hash = get_word_hash();
        my $separator_info = get_separator_info();
        
        my $normalized_occurrences = find_normalized_occurrences($xml_content, $word_hash, $separator_info);
        print Dumper($normalized_occurrences);
        $result->{result} = $normalized_occurrences;
        print_json($result);
    };
    
    if ($@) {
        $result->{status} = 'error';
        $result->{message} = "Error processing file: $@";
        print_json($result);
        exit 1;
    }
}

# Get timestamp
sub get_timestamp {
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @days = qw(Sun Mon Tue Wed Thu Fri Sat);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime();
    $year += 1900;
    return sprintf("%s %s %02d %02d:%02d:%02d %d", 
                  $days[$wday], $months[$mon], $mday, $hour, $min, $sec, $year);
}

# Print json with proper UTF-8 encoding
sub print_json {
    my ($data) = @_;
    binmode STDOUT, ':utf8';
    # print(Dumper($data->{"result"}));
    # my $json = JSON->new->pretty->canonical->utf8->encode($data);
    # $json =~ s/\\/\\/g;
    # print $json;
}

# Print usage
sub print_usage {
    print "Usage: $0 <input.xml>\n";
    print "Normalizes words in the given XML file according to predefined rules.\n\n";
    print "Arguments:\n";
    print "  <input.xml>  Path to the input XML file\n";
}

# Read xml file
sub read_xml_file {
    my ($file) = @_;
    
    open my $fh, '<', $file or die "Can't open file '$file': $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    $content =~ s/\r\n/\n/g;
    return $content;
}

# Get word hash
sub get_word_hash {
    tie my %word_hash, 'Tie::IxHash';
    %word_hash = (
        'normalisation' => 'normalization',
        'characterising' => 'characterizing',
        'analyze' => 'analyse',
        'summarised' => 'summarized',
        'utilise' => 'utilize',
        'realise' => 'realize',
        'minimise' => 'minimize',
        'minimisation' => 'minimization',
        'polarise' => 'polarize',
        'behavior' => 'behaviour',
        'color' => 'colour',
        'favor' => 'favour',
        'parameterisation' => 'parametrization',
        'parameterize' => 'parametrize',
        'artifact' => 'artefact',
        'adhoc' => 'ad hoc',
        'air mass' => 'airmass',
        'biassed' => 'biased',
        'broad band' => 'broad-band',
        'comptonization' => 'Comptonization',
        'datapoint' => 'data point',
        'Big Bang' => 'big bang',
        'black-hole' => 'black hole',
        'cartesian' => 'Cartesian',
        'halos' => 'haloes',
        'gray' => 'grey',
        'zero point' => 'zero-point',
        'cosmic-ray' => 'cosmic ray',
        'vs' => 'versus',
        'vs.' => 'versus',
        'sun spot' => 'sunspot',
        'X ray' => 'X-ray',
        'x ray' => 'X-ray',
        'gamma ray' => 'gamma-ray',
        'super giant' => 'supergiant',
        'travel time' => 'traveltime',
        'turn off' => 'turn-off',
        'wave band' => 'waveband',
        'wave function' => 'wavefunction',
        'wave length' => 'wavelength',
        'wave number' => 'wavenumber',
        'world wide web' => 'World Wide Web',
        'x axis' => 'x-axis',
        'star spot' => 'star-spot',
        'star burst' => 'starburst',
        'spin up' => 'spin-up',
        'spin down' => 'spin-down',
        'solar system' => 'Solar system',
        'space-time' => 'space&ndash;time',
        'Roche-lobe' => 'Roche lobe',
        'plane parallel' => 'plane-parallel',
        'path length' => 'path-length',
        'onto' => 'on to',
        'off axis' => 'off-axis',
        'north galactic pole' => 'North Galactic Pole',
        'northern hemisphere' => 'Northern hemisphere',
        'southern hemisphere' => 'Southern hemisphere',
        'northwest' => 'north-west',
        'north-south' => 'north&ndash;south',
        'nonetheless' => 'none the less',
        'Monte-Carlo' => 'Monte Carlo',
        'milky way' => 'Milky Way',
        'life time' => 'lifetime',
        'life-time' => 'lifetime',
        'least square fits' => 'least-squares fit',
        'hot spot' => 'hotspot',
        'light year' => 'light-year',
        'light hour' => 'light-hour',
        'light second' => 'light-second',
        'sight lines' => 'sightlines',
        'local group' => 'Local Group',
        'fundamental plane' => 'Fundamental Plane',
        'free-bound' => 'free&ndash;bound',
        'free-free' => 'free&ndash;free',
        'hamiltonian' => 'Hamiltonian',
        'gaussian' => 'Gaussian',
        'insofar' => 'in so far',
        'in situ' => 'in situ',
        'k correction' => 'k-correction',
        'K correction' => 'K-correction',
        'k-correction' => 'k-correction',
        'K-correction' => 'K-correction',
        'log normal' => 'lognormal',
        'log-normal' => 'lognormal',
        'near infrared' => 'near-infrared',
        'near IR' => 'near-IR',
        'flat field' => 'flat-field',
        'extra galactic' => 'extragalactic',
        'far infrared' => 'far-infrared',
        'far IR' => 'far-IR',
        'far ultraviolet' => 'far-ultraviolet',
        'far UV' => 'far-UV',
        'axis ratio' => 'axial ratio',
        'beam width' => 'beamwidth',
        'black body' => 'blackbody',
        'bright spot' => 'bright-spot',
        'break up' => 'breakup',
        'focussed' => 'focused',
        'cross section' => 'cross-section',
        'cross correlate' => 'cross-correlate',
        'Alfv´en' => 'Alfvén',
        'antennae' => 'antennas',
        'Bremsstrahlung' => 'bremsstrahlung',
        '\\partial' => '\\upartial',
        'cepheid' => 'Cepheid',
        'co-ordinate' => 'coordinate',
        'Coudè' => 'cooed',
        'database' => 'data base',
        'dataset' => 'data set',
        'disk' => 'disc',
        'earth' => 'Earth',
        'Echelle' => 'Echelle',
        'eigen value' => 'eigenvalue',
        'eigen frequency' => 'eigenfrequency'
    );
    
    return \%word_hash;
}

# Get separator info
sub get_separator_info {
    return {
        '-' => { type => 'hyphen', display => '-' },
        '&ndash;' => { type => 'hyphen', display => '&ndash;' },
        '&mdash;' => { type => 'hyphen', display => '&mdash;' },
        '--' => { type => 'hyphen', display => '--' },
        "-\\s*\\n\\s*" => { type => 'hyphen', display => '-\\n' },
        ' ' => { type => 'space', display => ' ' },
        '&nbsp;' => { type => 'space', display => '&nbsp;' },
        '&nbsp;&nbsp;' => { type => 'space', display => '&nbsp;&nbsp;' },
        '&#x00A0;' => { type => 'space', display => '&#x00A0;' },
        '&#160;' => { type => 'space', display => '&#160;' },
        '&#xa0;' => { type => 'space', display => '&#xa0;' },
        '&#xA0;' => { type => 'space', display => '&#xA0;' },
    };
}

# Find normalized occurrences
sub find_normalized_occurrences {
    my ($xml, $word_hash, $separator_info) = @_;
    tie my %normalized_occurrences, 'Tie::IxHash';
    my @final_list = ();
    while (my ($original, $normalized) = each %$word_hash) {
        if ($original =~ /[\s-]/) {
            my ($first, $second) = split /[\s-]/, $original, 2;
            my $is_hyphenated = $original =~ /-/;
            
            foreach my $sep (keys %$separator_info) {
             
                my $pattern = $first . $sep . $second;
                my $quoted_pattern = $sep =~ /\\n/ ? $pattern : quotemeta($pattern);
                
                my $working_xml = $xml;
                while ($working_xml =~ /$quoted_pattern/g) {
                    my $found_word = $&;
                    $normalized_occurrences{$found_word} = $normalized;
                    push @final_list, {$found_word => $normalized};
                }
            }
        } else {
            my $quoted_original = quotemeta($original);
            my $working_xml = $xml;
            while ($working_xml =~ /$quoted_original\b/g) {
                my $found_word = $&;
                $normalized_occurrences{$found_word} = $normalized;
                push @final_list, {$found_word => $normalized};
            }
        }
    }
    
    return \@final_list;
}

# Call the main function
main();
