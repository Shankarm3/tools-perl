{{ ... }}
sub process_bibcit_ids {
    my ($content, $ids_str) = @_;
    my @apt_ids = split /,/, $ids_str;
    my @sno_ids;
    
    foreach my $apt_id (@apt_ids) {
        if ($content =~ /<bib[^>]*?sno="([^"]+)"[^>]*?apt_id="\Q$apt_id\E"/) {
            push @sno_ids, $1;
        } else {
            warn "Warning: Could not find bib entry with apt_id=$apt_id\n";
        }
    }
    
    # Sort numerically if all are numbers, otherwise sort as strings
    if (@sno_ids && $sno_ids[0] =~ /^\d+$/) {
        return sort { $a <=> $b } @sno_ids;
    } else {
        return sort @sno_ids;
    }
}

sub find_consecutive_ranges {
    my @numbers = @_;
    return [] unless @numbers;
    
    # If the numbers are numeric, sort numerically
    if ($numbers[0] =~ /^\d+$/) {
        @numbers = sort { $a <=> $b } @numbers;
    } else {
        @numbers = sort @numbers;
    }
    
    my @ranges;
    my @current_range = ($numbers[0]);
    
    for my $i (1..$#numbers) {
        # Check if current number is consecutive with the last in current range
        if ($numbers[$i] =~ /^\d+$/ && $numbers[$i-1] =~ /^\d+$/) {
            # Numeric comparison
            if ($numbers[$i] == $numbers[$i-1] + 1) {
                push @current_range, $numbers[$i];
                next;
            }
        } else {
            # String comparison - check if they are sequential letters (a,b,c...)
            if (length($numbers[$i]) == 1 && length($numbers[$i-1]) == 1 &&
                ord($numbers[$i]) == ord($numbers[$i-1]) + 1) {
                push @current_range, $numbers[$i];
                next;
            }
        }
        
        # If we get here, numbers are not consecutive
        push @ranges, [@current_range];
        @current_range = ($numbers[$i]);
    }
    push @ranges, \@current_range if @current_range;
    
    return \@ranges;
}

sub extract_bib_info {
    my ($content, @sno_ids) = @_;
    my %bib_info;
    
    foreach my $sno (@sno_ids) {
        if ($content =~ /<bib\s+[^>]*?sno="\Q$sno\E"[^>]*?apt_id="([^"]+)"/) {
            my $apt_id = $1;
            $bib_info{$sno}{apt_id} = $apt_id;
            $bib_info{$sno}{sno} = $sno;
        } else {
            warn "Warning: Could not find bib entry with sno=$sno\n";
        }
    }
    
    return %bib_info;
}

# Update the main script to pass content to process_bibcit_ids
my $content = read_xml_file($xml_file);
$content =~ s/\s+/ /g;

my @bibcit_ids = process_bibcit_ids($content, $bibcit_ids_str);
{{ ... }}