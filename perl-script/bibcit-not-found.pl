we need one more parameter to the main script like bibcit, figcit, appcit etc
user will also pass this parameter the sequence will be like 

./citation_pattern_matcher.pl <xml_file> <bibcit_ids> <bibcit> <figcit> <appcit>

for now only capture it do not thorugh any error if not present or present 

if the bibcit ids are not found in the references during the current logic then we need to search in the reference section
<bib type="uno" id="<bibcit>"> need to loop thorugh all missing_references and capture the <au> tags inside and return these <au> instead of the missing ids


# In the main sub, update argument handling
my ($xml_file, $bibcit_ids, @ref_types) = @ARGV;

# Store reference types if provided
my $ref_types = {};
if (@ref_types) {
    $ref_types = {
        map { $_ => 1 } @ref_types
    };
}

sub get_authors_from_references {
    my ($xml, $missing_refs) = @_;
    my %authors;
    
    foreach my $ref_id (@$missing_refs) {
        if ($xml =~ /<bib\s+[^>]*\btype\s*=\s*["']uno["'][^>]*\bid\s*=\s*["']\Q$ref_id\E["'][^>]*>(.*?)<\/bib>/is) {
            my $ref_content = $1;
            my @authors;
            while ($ref_content =~ /<au>(.*?)<\/au>/gis) {
                my $au = $1;
                $au =~ s/<[^>]+>//g;  # Remove any inner tags
                $au =~ s/^\s+|\s+$//g;  # Trim whitespace
                push @authors, $au if $au;
            }
            $authors{$ref_id} = \@authors if @authors;
        }
    }
    
    return \%authors;
}

# After processing all bibcit IDs, check for missing references
if (@not_found_ids) {
    my $author_info = get_authors_from_references($xml_copy, \@not_found_ids);
    $output{missing_references} = {
        ids: \@not_found_ids,
        authors: $author_info
    };
}

# In the output generation
my %output = ( 
    status => @not_found_ids ? 'partial' : 'success',
    result => $final_output // [],
    message => @not_found_ids ? "Some references were not found" : "",
    timestamp => scalar localtime,
    reference_types => [@ref_types],  # Include the reference types that were processed
    stats => {
        total_requested => scalar @ids,
        found => scalar @ids - scalar @not_found_ids,
        missing => scalar @not_found_ids
    }
);

# Add author information for missing references
if (@not_found_ids) {
    my $author_info = get_authors_from_references($xml_copy, \@not_found_ids);
    $output{missing_references} = {
        ids: \@not_found_ids,
        authors: $author_info
    };
}

sub print_help {
    print <<"USAGE";
Citation Matcher v$CONFIG->{version}

Usage: $0 <xml_file> <bibcit_id1[,bibcit_id2,...]> [ref_type1 ref_type2 ...]

Options:
  -h, --help    Show this help message

Reference Types (optional):
  bibcit        Process bibliography citations (default)
  figcit        Process figure citations
  appcit        Process appendix citations

Examples:
  $0 input.xml bib1,bib2,bib3
  $0 input.xml bib1,bib2 figcit appcit

USAGE
}