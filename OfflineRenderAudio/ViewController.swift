//
//  ViewController.swift
//  OfflineRenderAudio
//
//  Created by Andrii Bala on 17.03.17.
//  Copyright © 2017 Andrii Bala. All rights reserved.
//

import UIKit
import AudioToolbox
import AVFoundation

class ViewControllerTwo: UIViewController {
    
    var mGraph: AUGraph?
    
    //Audio Unit References
    var mFilePlayer: AudioUnit?
    var mFilePlayer2: AudioUnit?
    
    var mReverb: AudioUnit?
    var mDelay: AudioUnit?
    var mTone: AudioUnit?
    var mMixer: AudioUnit?
    var mGIO: AudioUnit?
    
    //Audio File Location
    var inputFile: AudioFileID?
    var inputFile2: AudioFileID?
    
    //Audio file refereces for saving
    var extAudioFile: ExtAudioFileRef? = nil
    
    //Standard sample rate
    var graphSampleRate = Float64()
    var stereoStreamFormat864 = AudioStreamBasicDescription()
    var maxSampleTime = Float64()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        graphSampleRate = 44100.0
        maxSampleTime = 0.0
        
        let session = AVAudioSession.sharedInstance()
        if !(((try? session.setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)) != nil)) {
            // handle error
        }
        
        initializeAUGraph()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    func setupStereoStream864() {
        // The AudioUnitSampleType data type is the recommended type for sample data in audio
        // units. This obtains the byte size of the type for use in filling in the ASBD.
        let bytesPerSample: size_t = MemoryLayout.size(ofValue: UInt32.self)
        
        // Fill the application audio format struct's fields to define a linear PCM,
        // stereo, noninterleaved stream at the hardware sample rate.
        stereoStreamFormat864.mFormatID = kAudioFormatLinearPCM
        stereoStreamFormat864.mFormatFlags = kAudioFormatFlagIsPacked + kAudioFormatFlagIsSignedInteger
        stereoStreamFormat864.mBytesPerPacket = UInt32(bytesPerSample)
        stereoStreamFormat864.mFramesPerPacket = 1
        stereoStreamFormat864.mBytesPerFrame = UInt32(bytesPerSample)
        stereoStreamFormat864.mChannelsPerFrame = 2 // 2 indicates stereo
        stereoStreamFormat864.mBitsPerChannel = UInt32(8 * bytesPerSample)
        stereoStreamFormat864.mSampleRate = graphSampleRate
    }
    
    func initializeAUGraph() {
        setupStereoStream864()
        
        // Setup the AUGraph, add AUNodes, and make connections
        // create a new AUGraph
        NewAUGraph(&mGraph)
        
        // AUNodes represent AudioUnits on the AUGraph and provide an
        // easy means for connecting audioUnits together.
        var filePlayerNode = AUNode()
        var filePlayerNode2 = AUNode()
        
        var mixerNode = AUNode()
        var reverbNode = AUNode()
        var delayNode = AUNode()
        var toneNode = AUNode()
        var gOutputNode = AUNode()
        
        // file player component
        var filePlayer_desc = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Generator, subType: kAudioUnitSubType_AudioFilePlayer)
        
        // file player component2
        var filePlayer2_desc = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Generator, subType: kAudioUnitSubType_AudioFilePlayer)
        
        // Create AudioComponentDescriptions for the AUs we want in the graph
        // mixer component
        var mixer_desc = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Mixer, subType: kAudioUnitSubType_MultiChannelMixer)
        
        // Create AudioComponentDescriptions for the AUs we want in the graph
        // Reverb component
        var reverb_desc = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Effect, subType: kAudioUnitSubType_Reverb2)
        
        //tone component
        var tone_desc = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_FormatConverter, subType: kAudioUnitSubType_Varispeed)
        
        var gOutput_desc = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Output, subType: kAudioUnitSubType_GenericOutput)
        
        var delay_desc = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Effect, subType: kAudioUnitSubType_Delay)
        
        //Add nodes to graph
        // Add nodes to the graph to hold our AudioUnits,
        // You pass in a reference to the  AudioComponentDescription
        // and get back an  AudioUnit
        AUGraphAddNode(mGraph!, &filePlayer_desc, &filePlayerNode)
        AUGraphAddNode(mGraph!, &filePlayer2_desc, &filePlayerNode2)
        AUGraphAddNode(mGraph!, &mixer_desc, &mixerNode)
        AUGraphAddNode(mGraph!, &reverb_desc, &reverbNode)
        AUGraphAddNode(mGraph!, &delay_desc, &delayNode)
        AUGraphAddNode(mGraph!, &tone_desc, &toneNode)
        AUGraphAddNode(mGraph!, &gOutput_desc, &gOutputNode)
        
        //Open the graph early, initialize late
        // open the graph AudioUnits are open but not initialized (no resource allocation occurs here)
        AUGraphOpen(mGraph!)
        
        //Reference to Nodes
        // get the reference to the AudioUnit object for the file player graph node
        AUGraphNodeInfo(mGraph!, filePlayerNode, nil, &mFilePlayer)
        AUGraphNodeInfo(mGraph!, filePlayerNode2, nil, &mFilePlayer2)
        AUGraphNodeInfo(mGraph!, reverbNode, nil, &mReverb)
        AUGraphNodeInfo(mGraph!, delayNode, nil, &mDelay)
        AUGraphNodeInfo(mGraph!, toneNode, nil, &mTone)
        AUGraphNodeInfo(mGraph!, mixerNode, nil, &mMixer)
        AUGraphNodeInfo(mGraph!, gOutputNode, nil, &mGIO)
        
        AUGraphConnectNodeInput(mGraph!, filePlayerNode, 0, reverbNode, 0)
        AUGraphConnectNodeInput(mGraph!, reverbNode, 0, toneNode, 0)
        AUGraphConnectNodeInput(mGraph!, toneNode, 0, mixerNode, 0)
        AUGraphConnectNodeInput(mGraph!, filePlayerNode2, 0, mixerNode, 1)
        AUGraphConnectNodeInput(mGraph!, mixerNode, 0, delayNode, 0)
        AUGraphConnectNodeInput(mGraph!, delayNode, 0, gOutputNode, 0)
        
        // bus count for mixer unit input
        //Setup mixer unit bus count
        var busCount: UInt32 = 2
        AudioUnitSetProperty(mMixer!, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, UInt32(MemoryLayout.size(ofValue: busCount)))
        
        //Enable metering mode to view levels input and output levels of mixer
        var onValue: UInt32 = 1
        AudioUnitSetProperty(mMixer!, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Input, 0, &onValue, UInt32(MemoryLayout.size(ofValue: onValue)))
        
        // Increase the maximum frames per slice allows the mixer unit to accommodate the
        //    larger slice size used when the screen is locked.
        var maximumFramesPerSlice: UInt32 = 4096
        AudioUnitSetProperty(mMixer!, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, UInt32(MemoryLayout.size(ofValue: maximumFramesPerSlice)))
        
        // set the audio data format of tone Unit
        AudioUnitSetProperty(mTone!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &stereoStreamFormat864, UInt32(MemoryLayout.size(ofValue: AudioStreamBasicDescription())))
        
        // set the audio data format of reverb Unit
        AudioUnitSetProperty(mReverb!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &stereoStreamFormat864, UInt32(MemoryLayout.size(ofValue: AudioStreamBasicDescription())))
        
        // set initial delay
        let delayTime: AudioUnitParameterValue = 2
        AudioUnitSetParameter(mDelay!, kDelayParam_DelayTime, kAudioUnitScope_Global, 0, delayTime, 0)
        
        // set initial reverb
        let reverbTime: AudioUnitParameterValue = 2.5
        AudioUnitSetParameter(mReverb!, 4, kAudioUnitScope_Global, 0, reverbTime, 0)
        AudioUnitSetParameter(mReverb!, 5, kAudioUnitScope_Global, 0, reverbTime, 0)
        AudioUnitSetParameter(mReverb!, 0, kAudioUnitScope_Global, 0, 0, 0)
        
        var auEffectStreamFormat = AudioStreamBasicDescription()
        var asbdSize: UInt32 = UInt32(MemoryLayout.size(ofValue: auEffectStreamFormat))
        memset(&auEffectStreamFormat, 0, MemoryLayout.size(ofValue: auEffectStreamFormat))
        
        // get the audio data format from reverb
        AudioUnitGetProperty(mReverb!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &auEffectStreamFormat, &asbdSize)
        auEffectStreamFormat.mSampleRate = graphSampleRate
        
        // set the audio data format of mixer Unit
        AudioUnitSetProperty(mMixer!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &auEffectStreamFormat, UInt32(MemoryLayout.size(ofValue: auEffectStreamFormat)))
        
        AUGraphInitialize(mGraph!)
        
        setUpAUFilePlayer()
        setUpAUFilePlayer2()
    }
    
    func setUpAUFilePlayer() {
        let songPath: String? = Bundle.main.path(forResource: "MiAmor", ofType: "mp3")
        let songURL = URL(fileURLWithPath: songPath!)
        
        // open the input audio file
        AudioFileOpenURL(songURL as CFURL, .readPermission, 0, &inputFile)
        var fileASBD = AudioStreamBasicDescription()
        
        // get the audio data format from the file
        var propSize: UInt32 = UInt32(MemoryLayout.size(ofValue: fileASBD))
        AudioFileGetProperty(inputFile!, kAudioFilePropertyDataFormat, &propSize, &fileASBD)
        
        // tell the file player unit to load the file we want to play
        AudioUnitSetProperty(mFilePlayer!, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &inputFile, UInt32(MemoryLayout.size(ofValue: inputFile)))
        
        var nPackets = UInt64()
        var propsize: UInt32 = UInt32(MemoryLayout.size(ofValue: nPackets))
        AudioFileGetProperty(inputFile!, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets)
        
        // tell the file player AU to play the entire file
        let smpteTime = SMPTETime(mSubframes: 0, mSubframeDivisor: 0,
                                  mCounter: 0, mType: SMPTETimeType(rawValue: 0)!, mFlags: SMPTETimeFlags(rawValue: 0),
                                  mHours: 0, mMinutes: 0, mSeconds: 0, mFrames: 0)
        
        let timeStamp = AudioTimeStamp(mSampleTime: 0, mHostTime: 0, mRateScalar: 0,
                                       mWordClockTime: 0, mSMPTETime: smpteTime,
                                       mFlags: .sampleTimeValid, mReserved: 0)
        
        var rgn = ScheduledAudioFileRegion(mTimeStamp: timeStamp, mCompletionProc: nil,
                                           mCompletionProcUserData: nil, mAudioFile: inputFile!,
                                           mLoopCount: 0, mStartFrame: 0,
                                           mFramesToPlay: UInt32(nPackets) * fileASBD.mFramesPerPacket)
        
        memset(&rgn.mTimeStamp, 0, MemoryLayout.size(ofValue: rgn.mTimeStamp))
        
        if UInt32(maxSampleTime) < rgn.mFramesToPlay {
            maxSampleTime = Float64(rgn.mFramesToPlay)
        }
        
        AudioUnitSetProperty(mFilePlayer!, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &rgn, UInt32(MemoryLayout.size(ofValue: rgn)))
        
        // prime the file player AU with default values
        var defaultVal: UInt32 = 0
        
        AudioUnitSetProperty(mFilePlayer!, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultVal, UInt32(MemoryLayout.size(ofValue: defaultVal)))
        
        // tell the file player AU when to start playing (-1 sample time means next render cycle)
        var startTime = AudioTimeStamp()
        
        memset(&startTime, 0, MemoryLayout.size(ofValue: startTime))
        startTime.mFlags = .sampleTimeValid
        startTime.mSampleTime = -1
        
        AudioUnitSetProperty(mFilePlayer!, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, UInt32(MemoryLayout.size(ofValue: startTime)))
    }
    
    func setUpAUFilePlayer2() {
        
        let songPath: String? = Bundle.main.path(forResource: "500miles", ofType: "mp3")
        let songURL = URL(fileURLWithPath: songPath!)
        
        // open the input audio file
        AudioFileOpenURL(songURL as CFURL, .readPermission, 0, &inputFile2)
        var fileASBD = AudioStreamBasicDescription()
        
        // get the audio data format from the file
        var propSize: UInt32 = UInt32(MemoryLayout.size(ofValue: fileASBD))
        AudioFileGetProperty(inputFile2!, kAudioFilePropertyDataFormat, &propSize, &fileASBD)
        
        // tell the file player unit to load the file we want to play
        AudioUnitSetProperty(mFilePlayer2!, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &inputFile2, UInt32(MemoryLayout.size(ofValue: inputFile2)))
        
        var nPackets = UInt64()
        var propsize: UInt32 = UInt32(MemoryLayout.size(ofValue: nPackets))
        
        AudioFileGetProperty(inputFile2!, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets)
        
        // tell the file player AU to play the entire file
        let smpteTime = SMPTETime(mSubframes: 0, mSubframeDivisor: 0,
                                  mCounter: 0, mType: SMPTETimeType(rawValue: 0)!, mFlags: SMPTETimeFlags(rawValue: 0),
                                  mHours: 0, mMinutes: 0, mSeconds: 0, mFrames: 0)
        
        let timeStamp = AudioTimeStamp(mSampleTime: 0, mHostTime: 0, mRateScalar: 0,
                                       mWordClockTime: 0, mSMPTETime: smpteTime,
                                       mFlags: .sampleTimeValid, mReserved: 0)
        
        var rgn = ScheduledAudioFileRegion(mTimeStamp: timeStamp, mCompletionProc: nil,
                                           mCompletionProcUserData: nil, mAudioFile: inputFile2!,
                                           mLoopCount: 0, mStartFrame: 0,
                                           mFramesToPlay: UInt32(nPackets) * fileASBD.mFramesPerPacket)
        
        memset(&rgn.mTimeStamp, 0, MemoryLayout.size(ofValue: rgn.mTimeStamp))
        
        if UInt32(maxSampleTime) < rgn.mFramesToPlay {
            maxSampleTime = Float64(rgn.mFramesToPlay)
        }
        
        AudioUnitSetProperty(mFilePlayer2!, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &rgn, UInt32(MemoryLayout.size(ofValue: rgn)))
        
        // prime the file player AU with default values
        var defaultVal: UInt32 = 0
        AudioUnitSetProperty(mFilePlayer2!, kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0, &defaultVal, UInt32(MemoryLayout.size(ofValue: defaultVal)))
        
        // tell the file player AU when to start playing (-1 sample time means next render cycle)
        var startTime = AudioTimeStamp()
        
        memset(&startTime, 0, MemoryLayout.size(ofValue: startTime))
        startTime.mFlags = .sampleTimeValid
        startTime.mSampleTime = -1
        
        AudioUnitSetProperty(mFilePlayer2!, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, UInt32(MemoryLayout.size(ofValue: startTime)))
    }
    
    @IBAction func startRender(_ sender: UIButton) {
        // Gets the value of an audio format property.
        var destinationFormat = AudioStreamBasicDescription()
        
        memset(&destinationFormat, 0, MemoryLayout.size(ofValue: destinationFormat))
        destinationFormat.mChannelsPerFrame = 2
        destinationFormat.mFormatID = kAudioFormatMPEG4AAC
        
        var size: UInt32 = UInt32(MemoryLayout.size(ofValue: destinationFormat))
        var result: OSStatus = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &size, &destinationFormat)
        
        print("AudioFormatGetProperty \(result)")
        
        let fileName = NSUUID().uuidString
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = path.appendingPathComponent("\(fileName).m4a")
        let outputPath = url.path
        
        let outputURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, outputPath as CFString!, .cfurlposixPathStyle, false)
        print(outputURL!)
        
        // specify codec Saving the output in .m4a format
        result = ExtAudioFileCreateWithURL(outputURL!, kAudioFileM4AType, &destinationFormat, nil, AudioFileFlags.eraseFile.rawValue, &extAudioFile)
        
        print("ExtAudioFileCreateWithURL \(result)")
        
        // This is a very important part and easiest way to set the ASBD for the File with correct format.
        var clientFormat = AudioStreamBasicDescription()
        var fSize: UInt32 = UInt32(MemoryLayout.size(ofValue: clientFormat))
        memset(&clientFormat, 0, MemoryLayout.size(ofValue: clientFormat))
        
        // get the audio data format from the Output Unit
        AudioUnitGetProperty(mGIO!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &clientFormat, &fSize)
        
        // set the audio data format of mixer Unit
        ExtAudioFileSetProperty(extAudioFile!, kExtAudioFileProperty_ClientDataFormat, fSize, &clientFormat)
        
        // specify codec
        var codec: UInt32 = kAppleHardwareAudioCodecManufacturer
        ExtAudioFileSetProperty(extAudioFile!, kExtAudioFileProperty_CodecManufacturer, UInt32(MemoryLayout.size(ofValue: codec)), &codec)
        ExtAudioFileWriteAsync(extAudioFile!, 0, nil)
        
        pullGenericOutput()
        
    }
    
    func pullGenericOutput() {
        var flags: AudioUnitRenderActionFlags = AudioUnitRenderActionFlags(rawValue: 0)
        var inTimeStamp = AudioTimeStamp()
        
        memset(&inTimeStamp, 0, MemoryLayout.size(ofValue: inTimeStamp))
        inTimeStamp.mFlags = .sampleTimeValid
        
        let busNumber: UInt32 = 0
        var numberFrames: UInt32 = 512
        inTimeStamp.mSampleTime = 0
        let channelCount: Int = 2
        var totFrms: Int = Int(maxSampleTime)
        
        while totFrms > 0 {
            if UInt32(totFrms) < numberFrames {
                numberFrames = UInt32(totFrms)
            } else {
                totFrms -= Int(numberFrames)
            }
            
            let bufferList = AudioBufferList.allocate(maximumBuffers: Int(channelCount))
            for i in 0...channelCount-1 {
                var buffer = AudioBuffer()
                buffer.mNumberChannels = 1
                buffer.mDataByteSize = numberFrames * 4
                buffer.mData = calloc(Int(numberFrames), 4)
                bufferList[i] = buffer
            }
            
            AudioUnitRender(mGIO!, &flags, &inTimeStamp, busNumber, numberFrames, bufferList.unsafeMutablePointer)
            ExtAudioFileWrite(extAudioFile!, numberFrames, bufferList.unsafeMutablePointer)
            inTimeStamp.mSampleTime += Float64(numberFrames)
        }
        
        filesSavingCompleted()
    }
    
    func filesSavingCompleted() {
        let status: OSStatus = ExtAudioFileDispose(extAudioFile!)
        print("OSStatus(ExtAudioFileDispose): \(status)\n")
    }
}

extension ScheduledAudioFileRegion {
    init(mTimeStamp: AudioTimeStamp, mCompletionProc: ScheduledAudioFileRegionCompletionProc?, mCompletionProcUserData: UnsafeMutableRawPointer?, mAudioFile: OpaquePointer, mLoopCount: UInt32, mStartFrame: Int64, mFramesToPlay: UInt32) {
        self.mTimeStamp = mTimeStamp
        self.mCompletionProc = mCompletionProc
        self.mCompletionProcUserData = mCompletionProcUserData
        self.mAudioFile = mAudioFile
        self.mLoopCount = mLoopCount
        self.mStartFrame = mStartFrame
        self.mFramesToPlay = mFramesToPlay
    }
}

extension AudioComponentDescription {
    init(manufacturer: OSType, type: OSType, subType: OSType) {
        self.init(componentType: type, componentSubType: subType, componentManufacturer: manufacturer, componentFlags: 0, componentFlagsMask: 0)
    }
}
