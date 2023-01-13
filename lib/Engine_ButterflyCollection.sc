Engine_ButterflyCollection : CroneEngine {

    var <butterflies, <bus, <netPos, <eoc, <net, <mainBuffer;

    *new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

    alloc {
        "adding def".postln;
        SynthDef(\butterfly, { |out, buf, size, amp=0.4, attack=1, variation=0.1, release=1, gate=1|
            var env = Env.asr(attackTime: attack, releaseTime: release);
            var eg = EnvGen.kr(env, gate, doneAction: Done.freeSelf);
            var trigs = Impulse.kr(2.2*size.reciprocal);
            var bufDur = BufDur.kr(buf);
            var snd = GrainBuf.ar(
                numChannels: 2, 
                trigger: trigs,
                dur: size,
                sndbuf: buf,
                pos: ((bufDur - size)/bufDur) - (variation*LFNoise0.kr(2.2*size.reciprocal)),
                );
            Out.ar(out, amp.lag(attack/2)*eg*snd);

        }).add;

        bus = Bus.audio(context.server, 2);
        netPos = Bus.control(context.server, 1);
        mainBuffer = Buffer.alloc(context.server, 6*context.server.sampleRate);
        "play eoc".postln;
        eoc = {
            Out.ar(context.out_b, In.ar(bus, 2).tanh);
        }.play;

        "play net".postln;
        net = {
            var pos = Phasor.ar(start: 0.0, end: BufFrames.kr(mainBuffer));
            BufWr.ar(Mix.ar(SoundIn.ar([0, 1])), mainBuffer, pos);
            Out.kr(netPos, A2K.kr(pos));
        }.play;

        "collect butterflies".postln;
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

        this.addCommand("fly", "ifff", {|msg|
            this.fly(
                msg[1].asInteger,
                msg[2].asFloat,
                msg[3].asFloat,
                msg[4].asFloat);
        });

        this.addCommand("land", "if", { |msg|
            this.land(
                msg[1].asInteger,
                msg[2].asFloat,
            );
        });

    }

    fly { |b, size, amp, attack|
        var spot = butterflies[b];
        "fly %\n".postf(spot.syn);

        if(spot.syn.notNil, {"foo".postln}, {"bar".postln});
        "baz".postln;
        if (spot.syn.notNil, {
            spot.syn.set(\gate, 1, \size, size, \amp, amp);
        }, {
            spot.syn = Synth(\butterfly, [
                \out, bus,
                \buf, spot.buffer,
                \size, size,
                \amp, amp,
                \attack, attack,
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

    capture { |b|
        var spot = butterflies[b];
        "capturing".postln;
        netPos.get({ |now|
            "now is %".postf(now);
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
        netPos.free;
        net.free;
        bus.free;
        eoc.free;
    }
}