Prrplexor {
	classvar <voiceKeys;

	var <globalParams;
	var <voiceParams;
	var <voiceGroup;
	var <singleVoices;
	var <specFlatness;

	*initClass {
		voiceKeys = Array.fill(10, { arg i; (i+1).asSymbol });

		StartUp.add {
			var s = Server.default;

			s.waitForBoot {
				SynthDef.new(\prrplexor_osc, {
					var sig, envelope, panLFO, fbLFO, chain, flat;

					fbLFO = LFTri.ar(
						\fbFreq.kr(1),
						Rand(0, 2pi)
					);

					sig = SinOscFB.ar(
						\freq.kr(440),
						(\fb.kr(0) + (fbLFO * \fbAmp.kr(0)))
					);

					panLFO = SinOsc.ar(
						\panFreq.kr(1),
						Rand(0, 2pi)
					);

					envelope = EnvGen.kr(
						envelope: Env.asr(attackTime: \attack.kr(0.5), sustainLevel: \sustain.kr(1), releaseTime: \release.kr(1)),
						gate: \stopGate.kr(1),
						doneAction: 2
					);

					sig = sig * envelope * \amp.kr(0);

					chain = FFT(LocalBuf(1024), sig);
					flat = SpecFlatness.kr(chain);

					sig = Pan2.ar(sig, Clip.ar((\pan.kr(0) + (panLFO * \panAmp.kr(0))), -1, 1).lag3(\pan_slew.kr(0.5)));
					Out.ar(0, sig);
					Out.kr(\specFlatOut.kr(1), flat);
				}).add;
			}
		}
	}

	*new {
		^super.new.init;
	}

	init {

		var s = Server.default;

		voiceGroup = Group.new(s);

		globalParams = Dictionary[
			\fb -> 0,
			\amp -> 0.1,
			\attack -> 0.5,
			\pan -> 0,
			\panFreq -> 1,
			\panAmp -> 0,
			\fbFreq -> 1,
			\fbAmp -> 0,
			\sustain -> 1,
			\release -> 1
		];

		singleVoices = Dictionary.new;
		voiceParams = Dictionary.new;

		voiceKeys.do({ |voiceKey|
			singleVoices[voiceKey] = Group.new(voiceGroup);
			voiceParams[voiceKey] = Dictionary.newFrom(globalParams);
		});

		specFlatness = Bus.control(s);

		s.sync;
	}

	playVoice { |voiceKey, freq|
		// kill already playing voice
		singleVoices[voiceKey].set(\stopGate, -1.05); // -1.05 is 'forced release' with 50ms (0.05s) cutoff time
		voiceParams[voiceKey][\freq] = freq;

		Synth.new(\prrplexor_osc, [\freq, freq, \specFlatOut, specFlatness.index] ++ voiceParams[voiceKey].getPairs, singleVoices[voiceKey]);
	}

	trigger { |voiceKey, freq|
		if( voiceKey == 'all',{
			voiceKeys.do({ |vK|
				this.playVoice(vK, freq);
			});
		},
			{
				this.playVoice(voiceKey, freq);
			});
	}

	adjustVoice { arg voiceKey, paramKey, paramValue;
		singleVoices[voiceKey].set(paramKey, paramValue);
		voiceParams[voiceKey][paramKey] = paramValue
	}

	setParam { arg voiceKey, paramKey, paramValue;
		if( voiceKey == 'all',{
			voiceKeys.do({ |vK|
				this.adjustVoice(vK, paramKey, paramValue);
			});
		},
			{
				this.adjustVoice(voiceKey, paramKey, paramValue);
			});
	}

	// IMPORTANT SO OUR SYNTHS DON'T RUN PAST THE SCRIPT'S LIFE
	freeAllNotes {
		voiceGroup.set(\stopGate, -1.05);
	}

	free {
		// IMPORTANT
		voiceGroup.free;
	}
}