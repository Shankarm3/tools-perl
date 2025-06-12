use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use Tie::IxHash;


# Read the entire XML content
my $xml = do {
    local $/;
    open my $fh, '<', 'input.xml' or die "Can't open file: $!";
    <$fh>;
};
$xml =~ s/\r\n/\n/g;

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

# Separators to try between the split words
my %separator_info = (
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
);

# Created a tied hash to maintain insertion order
tie my %normalized_occurrences, 'Tie::IxHash';

# Process each word in the word hash
while (my ($original, $normalized) = each %word_hash) {
    if ($original =~ /[\s-]/) {
        my ($first, $second) = split /[\s-]/, $original, 2;
        my $is_hyphenated = $original =~ /-/;
        
        my @matching_separators = grep {
            $is_hyphenated ? 
                $separator_info{$_}{type} eq 'hyphen' : 
                $separator_info{$_}{type} eq 'space'
        } keys %separator_info;
        
        foreach my $sep (@matching_separators) {
            my $pattern = $first . $sep . $second;
            my $quoted_pattern = $sep =~ /\\n/ ? $pattern : quotemeta($pattern);
            
            my $working_xml = $xml;
            while ($working_xml =~ /$quoted_pattern/ig) {
                my $found_word = $&;
                $normalized_occurrences{$found_word} = $normalized;
            }
        }
    } else {
        my $quoted_original = quotemeta($original);
        my $working_xml = $xml;
                    print("original1========================> $quoted_original\n");
        while ($working_xml =~ /$quoted_original\b/ig) {
                    print("original2========================> $quoted_original\n");

            my $found_word = $&;
            $normalized_occurrences{$found_word} = $normalized;
        }
    }
}

# Example of how to use the hash:
print "Found the following word variations and their normalizations:\n";
while (my ($found, $normalized) = each %normalized_occurrences) {
    my $escaped_found = $found;
    $escaped_found =~ s/\n/\\n/g;
    # print "  '$escaped_found' => '$normalized'\n";
}

