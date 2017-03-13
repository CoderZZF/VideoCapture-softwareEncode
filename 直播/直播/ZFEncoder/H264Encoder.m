//
//  H264Encoder.m
//  直播
//
//  Created by zhangzhifu on 2017/3/13.
//  Copyright © 2017年 seemygo. All rights reserved.
//

#import "H264Encoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
//#import "avformat.h"
//#import "avcodec.h"

@interface H264Encoder ()

@end

@implementation H264Encoder

#pragma mark - 准备工作
- (void)prepareEncodeWithWidth:(int)width height:(int)height {
    // 1. 注册所有的存储格式和编码格式
    av_register_all();
    
    // 2. 创建AVFormatContext
    
    // 3. 创建AVStream
    
    // 4. 获取AVCodecContext
    
    // 5. 查找AVCodec
    
    // 6. 创建AVFrame -> AVPacket
}


- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer {
    
}


- (void)endEncode {
    
}
@end
