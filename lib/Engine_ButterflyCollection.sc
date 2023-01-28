
Engine_ButterflyCollection : CroneEngine {

    var <butterflies, <bus, <netPos, <eoc, <net, <mainBuffer, <rowBusses, <rowSynths;

    *new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

    alloc {
        SynthDef(\butterfly, { |out, buf, size, amp=0.4, attack=1, variation=0.1, release=1, gate=1, pan=0|
            var env = Env.asr(attackTime: attack, releaseTime: release, curve: [2, 0, -2]);
            var eg = EnvGen.kr(env, gate, doneAction: Done.freeSelf);
            var trigs = Impulse.kr(2.2*size.reciprocal);
            var bufDur = BufDur.kr(buf);
            var snd = GrainBuf.ar(
                numChannels: 2, 
                trigger: trigs,
                dur: size,
                sndbuf: buf,
                pos: (bufDur - size - (variation*LFNoise0.kr(2.2*size.reciprocal).range(0, 1)))/bufDur,
                pan: pan
                );
            Out.ar(out, amp.lag(attack/2)*eg*snd);

        }).add;

        SynthDef(\row, {|in, out, low=15000, lowQ=0.5, high=20, highQ=0.5|
            var snd = In.ar(in, 2);
            snd = RLPF.ar(snd, low, lowQ.reciprocal);
            snd = RHPF.ar(snd, high, highQ.reciprocal);
            Out.ar(out, Sanitize.ar(snd));
        }).add;

        SynthDef(\eoc, { |in, out|
            Out.ar(out, In.ar(in, 2).tanh);
        }).add;
        context.server.sync;
        bus = Bus.audio(context.server, 2);
        rowBusses = 8.collect {Bus.audio(context.server, 2)};
        netPos = Bus.control(context.server, 1);
        mainBuffer = Buffer.alloc(context.server, 6*context.server.sampleRate);
        //"eoc in % out %\n".postf(bus, context.out_b);
        eoc = Synth(\eoc, [\in, bus, \out, context.out_b]);
        // add after so before EOC.
        rowSynths = 8.collect { |i|
            //"row % in % out %\n".postf(i, rowBusses[i], bus);
            Synth(\row,[\in, rowBusses[i], \out, bus]);
        };

        net = {
            var pos = Phasor.ar(start: 0.0, end: BufFrames.kr(mainBuffer));
            BufWr.ar(Mix.ar(SoundIn.ar([0, 1])), mainBuffer, pos);
            Out.kr(netPos, A2K.kr(pos));
        }.play;

        butterflies = 128.collect({(
            buffer: Buffer.alloc(context.server, 2*context.server.sampleRate),
            syn: nil,
            size: 0.1,
            pinned: false,
        )});

        "add commands".postln;
        this.addCommand("capture", "i", { |msg|
            this.capture(msg[1].asInteger);
        });

        this.addCommand("fly", "ifffff", {|msg|
            this.fly(
                msg[1].asInteger,
                msg[2].asFloat,
                msg[3].asFloat,
                msg[4].asFloat,
                msg[5].asFloat,
                msg[6].asFloat);
        });

        this.addCommand("land", "if", { |msg|
            this.land(
                msg[1].asInteger,
                msg[2].asFloat,
            );
        });

        this.addCommand("copy", "ii", { |msg|
            this.copyButterfly(msg[1].asInteger, msg[2].asInteger)
        });

        this.addCommand("saveAudio", "s", { |msg|
            var path = msg[1].asString;
            butterflies.do { |b, i|
                if(b.pinned, {
                    b.buffer.write(
                        path ++ i ++ ".aiff", 
                        headerFormat: "AIFF", 
                        sampleFormat: "float", 
                        numFrames: -1, 
                        startFrame: 0, 
                        leaveOpen: false);
                });
            };
        });

        this.addCommand("loadAudio", "s", { |msg|
            var path = msg[1].asString;
            butterflies.do { |b, i|
                if(File.exists(path ++ i ++ ".aiff"), {
                    "reading %".postf(path ++ i ++ ".aiff");
                    b.buffer.read(
                        path ++ i ++ ".aiff", 
                        numFrames: b.buffer.numFrames,
                        leaveOpen: false);
                });
            };
        });     

        this.addCommand("filter", "iffff", {|msg|
            var row = msg[1].asInteger;
            var low = msg[2].asFloat;
            var lowQ = msg[3].asFloat;
            var high = msg[4].asFloat;
            var highQ = msg[5].asFloat;
            var rowSynth = rowSynths[row];
            // "setting low % high % on %".postf(low, high, rowSynth);
            rowSynth.set(\low, low, \lowQ, lowQ, \high, high, \highQ, highQ);
        });
    }

    fly { |b, size, amp, attack, variation, pan|
        var spot = butterflies[b];
        //"fly %\n".postf(spot.syn);
        if (spot.syn.notNil, {
            spot.syn.set(
                \gate, 1, 
                \size, size,
                \variation, variation,
                \amp, amp);
        }, {
            //"new synth to %\n".postf(rowBusses[(b/16).floor]);
            spot.syn = Synth(\butterfly, [
                \out, rowBusses[(b/16).floor],
                \buf, spot.buffer,
                \size, size,
                \variation, variation,
                \amp, amp,
                \attack, attack,
                \pan, pan
            ]);
            spot.syn.onFree({
                spot.syn = nil;
            });
        });
        "flew".postln;
    }

    land { |b, release|
        var spot = butterflies[b];
        spot.syn.notNil.if({
            spot.syn.set(\release, release, \gate, 0);
        }, {
            "already gone".postln;
        });
    }

    copyButterfly { |a, b|
        var from = butterflies[a];
        var to = butterflies[b];
        from.buffer.copyData(to.buffer);
    }

    capture { |b|
        var spot = butterflies[b];
        "capturing".postln;
        netPos.get({ |now|
            //"now is %".postf(now);
            now = now.floor;
            if (now > spot.buffer.numFrames, {
                mainBuffer.copyData(
                    spot.buffer, 
                    dstStartAt: 0, 
                    srcStartAt: now - spot.buffer.numFrames, 
                    numSamples: spot.buffer.numFrames);
            }, {
                mainBuffer.copyData(
                    spot.buffer,
                    dstStartAt: 0,
                    srcStartAt: mainBuffer.numFrames + now - spot.buffer.numFrames,
                    numSamples: spot.buffer.numFrames - now,
                );
                mainBuffer.copyData(
                    spot.buffer,
                    dstStartAt: spot.buffer.numFrames - now,
                    srcStartAt: 0,
                    numSamples: now,
                );          
            });
            spot.pinned = true;
            "captured".postln;
        });

    }

    // On capture, copy the past into a butterfly.
    // Then start a grain synth to play it.
    // Keep the grain synths as we go.


    free {
        butterflies.do { |b|
            b.syn.free;
            b.buffer.free;
        };
        rowSynths.do { |r|
            r.free;
        };
        rowBusses.do { |r|
            r.free;
        };
        netPos.free;
        net.free;
        bus.free;
        eoc.free;
    }
}