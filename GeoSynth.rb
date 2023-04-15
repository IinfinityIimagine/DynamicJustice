require "rtmidi"
require "time"

def selectPorts()
    while true
        midin = RtMidi::In.new
        puts "Select Input Device"
        midin.port_names.each_with_index { |name, i|
            puts "#{i} : #{name}"
        }
        if (port = gets) =~ /^\d+$/ and midin.port_names[port.to_i]
            midin.open_port(port.to_i)
            break
        end
        puts "Refreshing..."
    end
    while true
        midout = RtMidi::Out.new
        puts "Select Output Device"
        midout.port_names.each_with_index { |name, i|
            puts "#{i} : #{name}"
        }
        if (port = gets) =~ /^\d+$/ and midout.port_names[port.to_i]
            midout.open_port(port.to_i)
            break
        end
        puts "Refreshing..."
    end
    return midin, midout
end

$lastpitch = nil
$lock = Mutex.new

def shift(channel, pitch, velocity)
    $lock.synchronize {
        if velocity != 0
            if $lastpitch and (pitch - $lastpitch) % 12 != 0
                while (pitch - $lastpitch).abs > 6
                    pitch -= ((pitch - $lastpitch) <=> 0) * 12
                end
            end
            puts pitch
            puts $lastpitch
            $lastpitch = pitch
            puts pitch
            puts $lastpitch
            return pitch
        else
            (0...128).each { |i|
                $midout.send_channel_message(0x80 + channel, i, 0) if (i-pitch) % 12 == 0
            }
            return pitch
        end
    }
end

begin
    $midin, $midout = selectPorts
    $midin.receive_channel_message { |command, pitch, velocity|
        timestamp = Time.now.to_f
        puts "#{timestamp} : #{command} #{pitch} #{velocity} ----------- #{$lastpitch}"
        command -= 0x10 if command & ~0xF == 0x90 and velocity == 0
        $midout.send_channel_message(command, shift(command % 0xF, pitch, velocity), velocity)
        puts "---------------------------------------------------------- #{$lastpitch}"
    }
    sleep
rescue Interrupt => e
    puts e
    gets
rescue => e
    puts e
    gets
ensure
    $midin.close_port
    $midout.close_port
    puts "Ports Closed"
end