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

begin
    $midin, $midout = selectPorts
    16.times { |i|
        $midout.send_channel_message(0x90+i, 64+i, 64+3*i)
        sleep 0.2
        $midout.send_channel_message(0x80+i, 64+i, 0)
        sleep 0.5
    }
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