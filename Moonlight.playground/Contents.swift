// Copyright (c) 2016 Devin Roth
// Mods: Maciej Dobrzynski (github.com/dmattek)

// Octae numbers from 0 to 11
// Chooses 3 notes for a chord; root in 0-12 and then 3rd (+0,1,2) and 5th (+7, fixed)
// Chord - plays arpegiated chord on all 4 beats in the 4th octave
// Bass - plays first note of the chord for the duration of 4 beats in the 3rd octave
// Melody - plays random note from the chord in the 6th octave;
//          min duration 2 beats,
//          possible change on the 3rd beat, note played softer
//          possible change on the 4 beat, on the 3rd triplet of the arpegiated chord, played even softer
// Sustain released at the beginning of every beat

import Foundation
import CoreMIDI

//master controls
let seed = 0
let tempo = 20000000.0 / 60

// number of semitones in an octave
let nST = 12

// velocities and swing
let voicingNoteVelocityBase = 20
let voicingNoteVelocityMax = 20
let voicingNoteSwingMaxPerc = 5

let bassNoteVelocityBase = 20
let bassNoteVelocityMax = 20

let melodyNoteVelocityBase = 40
let melodyNoteVelocityMax = 20

// offsets in semitones w.r.t. 0-th note for bass, melody, and chord
let bassOffset = 3 * nST // octave offset w.r.t. chord that is chosen in 0-12 range

let melodyOffset = 6 * nST // offset for the melody
let melodyOffsetMax = 7 * nST // offset above which the melody note is played lower by an octave

let voicingOffset = 4 * nST // offset for the chord
let voicingOffsetMax = 5 * nST // offset above which play the voicing note lower by an octave


let pedalValue = 64
let pedalVelocity = 127

// variable initialisation
var chord = [0,0,0]
var voicing = [0,0,0]
var melody = 0
var melodyVelocity = 0
var bass = 0
var bassVelocity = 0
var voicingNoteSwing = 0.0
var voicingNoteVelocity = 0

//midi setup
var client = MIDIClientRef()
var source = MIDIEndpointRef()
let midiChPiano = 144
let midiChPedal = 176

MIDIClientCreate("GenerativeMusic" as CFString, nil, nil, &client)
MIDISourceCreate(client, "Moonlight" as CFString, &source)

sleep(1)    //wait until midi is set up

func midiOut(_ status:Int, byte1: Int, byte2:Int) {
    var packet = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
    let packetList = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: 1)
    let midiDataToSend:[UInt8] = [UInt8(status), UInt8(byte1), UInt8(byte2)];
    packet = MIDIPacketListInit(packetList);
    packet = MIDIPacketListAdd(packetList, 1024, packet, 0, 3, midiDataToSend);
    
    MIDIReceived(source, packetList)
    packet.deinitialize(count: 1)
    packetList.deinitialize(count: 1)
    packetList.deallocate()
}

// random number generator
srand48(seed)
func random(_ limit: Int)->Int {
    let limit = Double(limit) - 1
    return Int(round(drand48()*limit))
}

// chord generator
// chooses 3 random notes for the chord
// root in 0-12
// 3rd +3,4 st (random)
// 5th +7 st (fixed)
func generateChord()->[Int]{
    let root = random(nST)
    let third = root + 3 + random(2)
    let fifth = root + 7

    return [root,third,fifth]
}

// melody generator
// chooses random note from the chord and plays it with an offset
func generateMelody(_ chord: [Int]) -> Int {
    var melody = chord[random(3)] + melodyOffset
    if melody > melodyOffsetMax {
        melody -= nST
    }
    return melody
}

// voice chord
// offsets chord notes; brings down by an offset if above a threshold
func createVoicing(_ chord: [Int]) -> [Int] {
    var voicing = chord
    for note in 0..<voicing.count {
        voicing[note] += voicingOffset
        
        // if chord's note above a threshold, bring it down by an octave
        if voicing[note] > voicingOffsetMax {
            voicing[note] -= nST
        }
    }
    return voicing.sorted()
}


while true {
    chord = generateChord()
    voicing = createVoicing(chord)
    
    // melody note
    
    melody = generateMelody(chord)
    melodyVelocity = melodyNoteVelocityBase + random(melodyNoteVelocityMax)
    midiOut(midiChPiano, byte1: melody, byte2: melodyVelocity) // melody note on
    
    // bass note
    // the first note of the chord played with an offset and random velocity
    bass = chord[0] + bassOffset
    bassVelocity = bassNoteVelocityBase + random(bassNoteVelocityMax)
    midiOut(midiChPiano, byte1: bass, byte2: bassVelocity) // bass note on
    
    for beat in 1...4 {
        
        // 1st random change of melody; on the 3rd beat; 1/2 chance
        // if played, it's softer, velocity-5
        if beat == 3 {
            if random(2) == 0 {
                midiOut(midiChPiano, byte1: melody, byte2: 0) // melody note off
                
                melody = generateMelody(chord)
                midiOut(midiChPiano, byte1: melody, byte2: melodyVelocity - 5) // melody note on
            }
        }
        
        // Play each note of the arpegiated chord
        // and a possible melody change on the 4th beat + 2/3
        for triplet in 1...3 {
            
            // 2nd random change of melody; on the 4th beat + 2/3; 1/3 chance
            // if played, it's softer, velocity-10
            if beat == 4 && triplet == 3 {
                if random(3) == 0 {
                    midiOut(midiChPiano, byte1: melody, byte2: 0) // melody note off
                    
                    melody = generateMelody(chord)
                    midiOut(midiChPiano, byte1: melody, byte2: melodyVelocity - 10) // melody note on
                }
            }
            
            voicingNoteVelocity = voicingNoteVelocityBase + random(voicingNoteVelocityMax)
            midiOut(midiChPiano, byte1: voicing[triplet - 1], byte2: voicingNoteVelocity) // voicing note on
            
            // length of the note with random percentage swing added
            voicingNoteSwing = tempo * (1.0 + Double(random(voicingNoteSwingMaxPerc)) / 100.0)
            usleep(useconds_t(voicingNoteSwing))
            
            midiOut(midiChPedal, byte1: pedalValue, byte2: pedalVelocity) // pedal on
            midiOut(midiChPiano, byte1: voicing[triplet - 1], byte2: 0) // voicing note off
        }
    }
    
    midiOut(midiChPiano, byte1: melody, byte2: 0) // melody note off
    midiOut(midiChPiano, byte1: bass, byte2: 0) // bass note off
    midiOut(midiChPedal, byte1: pedalValue, byte2: 0) // pedal off
}

