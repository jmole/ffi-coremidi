#!/usr/bin/env ruby

module CoreMIDI

  #
  # Output device class
  #
  class Output

    include Device

    # close this output
    def close
      Map.MIDIClientDispose( @client )
      @enabled = false
    end

    # sends a MIDI message comprised of a String of hex digits
    def puts_bytestr(data)
    end

    # sends a MIDI messages comprised of Numeric bytes
    def puts_bytes(*data)
      format = "C" * args.size
      bytes = FFI::MemoryPointer.new FFI.type_size(:char) * args.size
      bytes.write_string(args.pack(format))

      packet_list = FFI::MemoryPointer.new(256)
      packet_ptr = Map.MIDIPacketListInit(packet_list)

      if SnowLeopard
        packet_ptr = Map.MIDIPacketListAdd(packet_list, 256, packet_ptr, 0, args.size, bytes)
      else
        # Pass in two 32-bit 0s for the 64 bit time
        packet_ptr = Map.MIDIPacketListAdd(packet_list, 256, packet_ptr, 0, 0, args.size, bytes)
      end

      Map.MIDISend( @outport, @destination, packet_list )
    end

    # send a MIDI message of an indeterminant type
    def puts(*a)
  	  case a.first
        when Array then puts_bytes(*a.first)
    	  when Numeric then puts_bytes(*a)
    	  when String then puts_bytestr(*a)
      end
    end
    alias_method :write, :puts

    # enable this device; also takes a block
    def enable(options = {}, &block)
      client_name = Map::CF.CFStringCreateWithCString( nil, "MIDIator", 0 )

      client_ptr = FFI::MemoryPointer.new :pointer
      Map.MIDIClientCreate client_name, nil, nil, client_ptr
      @client = client_ptr.read_pointer

      port_name = Map::CF.CFStringCreateWithCString nil, "Output", 0
      outport_ptr = FFI::MemoryPointer.new :pointer
      Map.MIDIOutputPortCreate @client, port_name, outport_ptr
      @outport = outport_ptr.read_pointer

      number_of_destinations = Map.MIDIGetNumberOfDestinations
      raise MIDIator::NoMIDIDestinations if number_of_destinations < 1
      @destination = Map.MIDIGetDestination( 0 )
      @enabled = true
      unless block.nil?
      	begin
      		block.call(self)
      	ensure
      		close
      	end
      end
    end
    alias_method :open, :enable
    alias_method :start, :enable

    def self.first
      Device.first(:output)
    end

    def self.last
      Device.last(:output)
    end

    def self.all
      Device.all_by_type[:output]
    end
  end

end