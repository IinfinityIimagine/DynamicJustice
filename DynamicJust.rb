#!ruby

require "rtmidi"
require "time"

def selectPorts()
    while true
        midin = RtMidi::In.new
        puts "Select Input Device"
        midin.port_names.each_with_index { |name, i|
            puts "#{i} : #{name}"
        }
        if (inport = STDIN.gets) =~ /^\d+$/ and midin.port_names[inport.to_i]
            puts "Input midi from #{midin.port_names[inport.to_i]}"
            midin.open_port(inport.to_i)
            break
        end
        puts "Invalid Input. Refreshing..."
    end
    while true
        midout = RtMidi::Out.new
        puts "Select Output Device"
        midout.port_names.each_with_index { |name, i|
            puts "#{i} : #{name}"
        }
        if (outport = STDIN.gets) =~ /^\d+$/ and midout.port_names[outport.to_i]
            puts "Output midi to #{midout.port_names[outport.to_i]}"
            midout.open_port(outport.to_i)
            break
        end
        puts "Invalid Input. Refreshing..."
    end
    return midin, midout
end

# just intonations
$limit7 = [1, 16.0/15, 9.0/8, 6.0/5, 5.0/4, 4.0/3, 7.0/5, 3.0/2, 8.0/5, 5.0/3, 7.0/4, 15.0/8]
$limit5 = [1, 16.0/15, 9.0/8, 6.0/5, 5.0/4, 4.0/3, 64.0/45, 3.0/2, 8.0/5, 5.0/3, 9.0/5, 15.0/8]

# brute force discreet logarithm
def dlog(gen, n, target)
    idx = 0
    val = 0
    while val != target
        idx += 1
        val += gen
        val %= n
    end
    return idx
end

$circle_of_fifths = (0...12).map { |x|  dlog(7, 12, x)  }

def meantone_gen(cof, gen)
    ratio = gen**cof
    raise "invalid tuning ratio" if ratio <= 0
    ratio /= 2 while ratio >= 2
    ratio *= 2 while ratio < 1
    return ratio
end

$generator12 = 2**(7.0/12)
$generator5 = 3.0/2
# $generator4 = 3.0/2 * (81.0/80) ** (-1.0/4)
$generator4 = 5.0**(1.0/4)
# $generator3 = 3.0/2 * (81.0/80) ** (-1.0/3)
$generator3 = (10.0/3)**(1.0/3)
# $generator2 = 3.0/2 * (81.0/80) ** (-1.0/2)
$generator2 = (20.0/9)**(1.0/2)

$meantone12 = $circle_of_fifths.map { |x| meantone_gen(x, $generator12)  }
$meantone5 = $circle_of_fifths.map { |x| meantone_gen(x, $generator5)  }
$meantone4 = $circle_of_fifths.map { |x| meantone_gen(x, $generator4)  }
$meantone3 = $circle_of_fifths.map { |x| meantone_gen(x, $generator3)  }

$equal = $meantone12
$pythagorean = $meantone5
$quarter_meantone = $meantone4
$third_meantone = $meantone3

$tuningRegistry = {
    "equal" => $equal,
    "eq" => $equal,
    "12tet" => $equal,
    "12" => $equal,
    "meantone12" => $equal,
    "12meantone" => $equal,

    "5limit" => $limit5,
    "limit5" => $limit5,
    "just5" => $limit5,
    "5just" => $limit5,

    "7limit" => $limit7,
    "limit7" => $limit7,
    "just7" => $limit7,
    "7just" => $limit7,

    "pythagorean" => $pythagorean,
    "meantone5" => $pythagorean,
    "quintalmeantone" => $pythagorean,
    "fifthmeantone" => $pythagorean,

    "meantone4" => $meantone4,
    "quartermeantone" => $meantone4,
    "quartalmeantone" => $meantone4,
    "fourthmeantone" => $meantone4,

    "meantone3" => $meantone3,
    "thirdmeantone" => $meantone3,

    "meantone2" => $meantone2,
    "secondmeantone" => $meantone2,
}

$cannonicalTunings = [
    "12-TET",
    "5-limit",
    "7-limit",
    "pythagorean",
    "quarter meantone",
    "third meantone",
    "second meantone",
]

def getTuning(name)
    return name ? $tuningRegistry[name.delete('^A-Za-z0-9').downcase] : nil
end

def selectTuning(args)
    tuning = getTuning args[0]
    monophonic = getTuning args[1]
    while not tuning
        puts "Select Tuning:"
        $cannonicalTunings.each_with_index { |name, i|
            puts "#{i} : #{name}"
        }
        if (canon = STDIN.gets) =~ /^\d+$/ and $cannonicalTunings[canon.to_i]
            puts "Tuning harmony according to #{$cannonicalTunings[canon.to_i]}"
            tuning = getTuning $cannonicalTunings[canon.to_i]
            break
        end
        puts "Invalid Input. Please try again..."
    end
    while not monophonic
        puts "Select Default Tuning for Monophonic Playing:"
        $cannonicalTunings.each_with_index { |name, i|
            puts "#{i} : #{name}"
        }
        if (canon = STDIN.gets) =~ /^\d+$/ and $cannonicalTunings[canon.to_i]
            puts "Tuning monophonic playing according to #{$cannonicalTunings[canon.to_i]}"
            monophonic = getTuning $cannonicalTunings[canon.to_i]
            break
        end
        puts "Invalid Input. Please try again..."
    end
    return tuning, monophonic
end


$lock = Mutex.new

def complexity(frac, limit)
    raise "ratio out of range" if frac >=2 or frac < 1
    den = 1
    num = frac
    while den < limit and num != num.to_i
        den += 1
        num = frac * den
    end
    raise "failed to decompose fraction" if frac != num/den and den < limit
    return num.to_i * (1 + 1.0/limit) + den - 2
end

def basis(pitch)
    consonances = $active.map { |note|
        note ? $consonance[(pitch-note[1])%12] : $maxcons
    }
    ret = $active[consonances.rindex(consonances.min)]
    return ret if ret
    return [440, 69, 69, 0] if $monophonic != $equal
    return [440.0 * 2 ** ((pitch - 69) / 12) * $monophonic[(pitch-69) % 12], pitch, pitch, 0]
end

def tune(pitch)
    freq, ref, _, num = basis(pitch)
    freq *= $tuning[(pitch-ref).round() % 12] # * 2 ** ((pitch-ref).round() / 12)
    ref_key = 69 + (Math.log(freq/440.0, 2) * 12).round()
    ref = 440.0 * 2 ** (((ref_key - 69).round() % 12).to_f / 12)
    adjust = (Math.log(freq/ref, 2) * 12 * 0x1000).round() + 0x2000
    throw "Error" if adjust >= 0x2800 or adjust <= 0x1800
    msb = adjust >> 7
    lsb = adjust & 0x7F
    puts "Just:#{freq}, 12TET:#{ref}, msb:#{msb}, lsb:#{lsb}"
    return freq, msb, lsb, ref_key, num
end

def updateTuning!(command, pitch)
    slot = (pitch - 69).round() % 12
    octave = (pitch - 69).round() - slot
    freq, msb, lsb, ref, num = tune pitch
    $active[slot] = [freq, pitch, ref, num + 1]
    $midout.send_channel_message(0xE0 | slot, lsb, msb)
    return command & ~0xF | slot, ref + octave
end

def find!(pitch)
    timestamp = Time.now.to_f
    puts "#{timestamp} : FINDING #{pitch}"
    channel = (pitch - 69).round() % 12
    octave = (pitch - 69).round() - channel
    note = $active[channel]
    throw "Error: Not found" if note[3] < 1
    puts "FOUND"
    pitch = note[2]
    note[3] -= 1
    puts "c:#{channel} p:#{pitch+octave}"
    return channel, pitch + octave
end

begin
    $tuning, $monophonic = selectTuning ARGV
    $active = $monophonic.each_with_index.map { |ratio, i|  [440 * ratio, 69 + i, 69 + i, 0]  }
    $consonance = $tuning.map { |f| complexity(f, 10**5) }
    $maxcons = $consonance.max+1
    $midin, $midout = selectPorts
    $midin.receive_channel_message { |command, pitch, velocity|
        timestamp = Time.now.to_f
        puts "#{timestamp} : #{command} #{pitch} #{velocity}"
        command -= 0x10 if command & ~0xF == 0x90 and velocity == 0
        $lock.synchronize {
            begin
            case command & ~0xF
                when 0x80 then
                    channel, pitch = find!(pitch)
                    $midout.send_channel_message(command & ~0xF | channel, pitch, velocity)
                when 0x90 then
                    command, pitch = updateTuning!(command, pitch)
                    $midout.send_channel_message(command, pitch, velocity)
                else    (0...16).each { |channel|  $midout.send_channel_message(command & ~0xF | channel, pitch, velocity) }
            end
            rescue => e
                puts e
            ensure
                puts $active.to_s
            end
        }
    }
    sleep
rescue Interrupt => e
    puts e
    STDIN.gets
rescue => e
    puts e
    STDIN.gets
ensure
    $midin.close_port
    $midout.close_port
    puts "Ports Closed"
end
