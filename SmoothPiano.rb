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

$timeout = 0.05
$bounce = 0.1
$lock = Mutex.new

$state = Array.new(128, [128, 0.0, nil])

def smooth(command, pitch, timestamp)
    $lock.synchronize{
        begin
            oldstate = $state[pitch].clone
            $state[pitch] = [command, timestamp, oldstate[2]]
            if oldstate[0] == command
                $state[pitch] = oldstate
                $state[pitch][2].exit if $state[pitch][2]
                return false
            elsif command == 128
                $state[pitch] = oldstate
                thr = Thread.new { sleep $bounce; $state[pitch][0] = 128; $midout.send_channel_message(128, pitch, 0) }
                $state[pitch][2].exit if $state[pitch][2]
                $state[pitch][2] = thr
                return false
            elsif oldstate[1] + $timeout < timestamp
                $state[pitch][2].exit if $state[pitch][2]
                return true
            else
                return false
            end
        rescue => e
            puts e
        end
    }
end

begin
    $midin, $midout = selectPorts
    $midin.receive_channel_message { |command, pitch, velocity|
        timestamp = Time.now.to_f
        puts "#{timestamp} : #{command} #{pitch} #{velocity}"
        command -= 0x10 if command & ~0xF == 0x90 and velocity == 0
        $midout.send_channel_message(command, pitch, velocity) if smooth(command, pitch, timestamp)
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