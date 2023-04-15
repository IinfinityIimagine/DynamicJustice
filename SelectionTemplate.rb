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
    $midin.receive_channel_message { |command, pitch, velocity|
        timestamp = Time.now.to_f
        puts "#{timestamp} : #{command} #{pitch} #{velocity}"
        $midout.send_channel_message(command, pitch, velocity)
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