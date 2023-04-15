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

$lock = Mutex.new

$audible_range = 36..96
$cc_range = 105

$up_keys = [14, 16, 19, 21, 23, 26, 28, 31, 33]
$down_keys = $up_keys.map { |i| i - 1 }
$preset_control = [9, 10, 11]

$snap_adjust = 1

$snap_points = (0..16)
$snap_points = $snap_points.map { |i| $snap_adjust + i * 128 / ($snap_points.size - 1) }
$snap_points[0] = 0
$snap_points[-1] = 127

Ndrawbars = 9
DefaultPreset = [$snap_points.size - 1] * 4 + [0] * 5
$preset_index = 0
$drawbars = File.file?("presets.drawbars") ? eval(File.read "presets.drawbars") : [DefaultPreset]
$drawbars.map! { |arr| (arr + [0] * Ndrawbars)[0...Ndrawbars] }

def increase_drawbar(idx)
    $drawbars[$preset_index][idx] += 1 unless $drawbars[$preset_index][idx] == $snap_points.size - 1
    puts "Updating preset : #{$drawbars[$preset_index].map { |i| i * 0.5}}"
    return $drawbars[$preset_index][idx]
end

def decrease_drawbar(idx)
    $drawbars[$preset_index][idx] -= 1 unless $drawbars[$preset_index][idx] == 0
    puts "Updating preset : #{$drawbars[$preset_index].map { |i| i * 0.5}}"
    return $drawbars[$preset_index][idx]
end

def update_preset()
    puts "Updating preset : #{$drawbars[$preset_index].map { |i| i * 0.5}}"
    $drawbars[$preset_index].each_with_index { |value, idx|
        $midout.send_channel_message(0xB0, $cc_range + idx, $snap_points[value])
    }
end

$actions = {}
$up_keys.each_with_index { |key, idx|
    $actions[key] = lambda { 
        $midout.send_channel_message(0xB0, $cc_range + idx, $snap_points[increase_drawbar(idx)])
    }
}
$down_keys.each_with_index { |key, idx|
    $actions[key] = lambda { 
        $midout.send_channel_message(0xB0, $cc_range + idx, $snap_points[decrease_drawbar(idx)])
    }
}
$actions[$preset_control[0]] = lambda {
    $preset_index = $drawbars.size
    $drawbars += [DefaultPreset]
    update_preset()
}
$actions[$preset_control[1]] = lambda {
    $preset_index -= 1 unless $preset_index == 0
    update_preset()
}
$actions[$preset_control[2]] = lambda {
    $preset_index += 1 unless $preset_index == $drawbars.size - 1
    update_preset()
}

begin
    $midin, $midout = selectPorts
    $midin.receive_channel_message { |command, pitch, velocity|
    timestamp = Time.now.to_f
        puts "#{timestamp} : #{command} #{pitch} #{velocity}"
        if ((command & ~0xF != 0x90) or (velocity == 0) or ($audible_range.include? pitch))
            $midout.send_channel_message(command, pitch, velocity)
        elsif $actions.include? pitch
            $lock.synchronize { $actions[pitch].call() }
        end
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
    puts "Writing Presets to File..."
    File.write("presets.drawbars", $drawbars.to_s)
    puts "Done"
end