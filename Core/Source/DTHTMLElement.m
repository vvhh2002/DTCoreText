//
//  DTHTMLElement.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 4/14/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "DTCoreText.h"
#import "DTHTMLElement.h"
#import "DTHTMLElementAttachment.h"
#import "DTHTMLElementBR.h"
#import "DTHTMLElementHR.h"
#import "DTHTMLElementLI.h"
#import "DTHTMLElementStylesheet.h"
#import "DTHTMLElementText.h"
#import "NSString+DTUtilities.h"

@interface DTHTMLElement ()

@property (nonatomic, strong) NSMutableDictionary *fontCache;
@property (nonatomic, strong) NSString *linkGUID;

- (DTCSSListStyle *)calculatedListStyle;

// internal initializer
- (id)initWithName:(NSString *)name attributes:(NSDictionary *)attributes options:(NSDictionary *)options;

@end

BOOL ___shouldUseiOS6Attributes = NO;

NSDictionary *_classesForNames = nil;

@implementation DTHTMLElement

+ (void)initialize
{
	// lookup table so that we quickly get the correct class to instantiate for special tags
	NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] init];
	
	[tmpDict setObject:[DTHTMLElementBR class] forKey:@"br"];
	[tmpDict setObject:[DTHTMLElementHR class] forKey:@"hr"];
	[tmpDict setObject:[DTHTMLElementLI class] forKey:@"li"];
	[tmpDict setObject:[DTHTMLElementStylesheet class] forKey:@"style"];
	[tmpDict setObject:[DTHTMLElementAttachment class] forKey:@"img"];
	[tmpDict setObject:[DTHTMLElementAttachment class] forKey:@"object"];
	[tmpDict setObject:[DTHTMLElementAttachment class] forKey:@"video"];
	[tmpDict setObject:[DTHTMLElementAttachment class] forKey:@"iframe"];
	
	_classesForNames = [tmpDict copy];
}

+ (DTHTMLElement *)elementWithName:(NSString *)name attributes:(NSDictionary *)attributes options:(NSDictionary *)options
{
	// look for specialized class
	Class class = [_classesForNames objectForKey:name];
	
	// use generic of none found
	if (!class)
	{
		class = [DTHTMLElement class];
	}
	
	DTHTMLElement *element = [[class alloc] initWithName:name attributes:attributes options:options];
	
	return element;
}

- (id)initWithName:(NSString *)name attributes:(NSDictionary *)attributes options:(NSDictionary *)options
{
	// node does not need the options, but it needs the name and attributes
	self = [super initWithName:name attributes:attributes];
	if (self)
	{
	}
	
	return self;
}

- (NSDictionary *)attributesDictionary
{
	NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
	
	BOOL shouldAddFont = YES;
	
	// copy additional attributes
	if (_additionalAttributes)
	{
		[tmpDict setDictionary:_additionalAttributes];
	}
	
	// add text attachment
	if (_textAttachment)
	{
#if TARGET_OS_IPHONE
		// need run delegate for sizing (only supported on iOS)
		CTRunDelegateRef embeddedObjectRunDelegate = createEmbeddedObjectRunDelegate(_textAttachment);
		[tmpDict setObject:CFBridgingRelease(embeddedObjectRunDelegate) forKey:(id)kCTRunDelegateAttributeName];
#endif		
		
		// add attachment
		[tmpDict setObject:_textAttachment forKey:NSAttachmentAttributeName];
		
		// remember original paragraphSpacing
		[tmpDict setObject:[NSNumber numberWithFloat:self.paragraphStyle.paragraphSpacing] forKey:DTAttachmentParagraphSpacingAttribute];
		
#ifndef DT_ADD_FONT_ON_ATTACHMENTS
		// omit adding a font unless we need it also on attachments, e.g. for editing
		shouldAddFont = NO;
#endif
	}
	
	// otherwise we have a font
	if (shouldAddFont)
	{
		CTFontRef font = [_fontDescriptor newMatchingFont];
			
		if (font)
		{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
			if (___useiOS6Attributes)
			{
				UIFont *uiFont = [UIFont fontWithCTFont:font];
				[tmpDict setObject:uiFont forKey:NSFontAttributeName];
			}
			else
#endif
			{
				// __bridge since its already retained elsewhere
				[tmpDict setObject:(__bridge id)(font) forKey:(id)kCTFontAttributeName];
			}
			
			
			// use this font to adjust the values needed for the run delegate during layout time
			[_textAttachment adjustVerticalAlignmentForFont:font];
			
			CFRelease(font);
		}
	}
	
	// add hyperlink
	if (_link)
	{
		[tmpDict setObject:_link forKey:DTLinkAttribute];
		
		// add a GUID to group multiple glyph runs belonging to same link
		[tmpDict setObject:_linkGUID forKey:DTGUIDAttribute];
	}
	
	// add anchor
	if (_anchorName)
	{
		[tmpDict setObject:_anchorName forKey:DTAnchorAttribute];
	}
	
	// add strikout if applicable
	if (_strikeOut)
	{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			[tmpDict setObject:[NSNumber numberWithInteger:NSUnderlineStyleSingle] forKey:NSStrikethroughStyleAttributeName];
		}
		else
#endif
		{
			[tmpDict setObject:[NSNumber numberWithBool:YES] forKey:DTStrikeOutAttribute];
		}
	}
	
	// set underline style
	if (_underlineStyle)
	{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			[tmpDict setObject:[NSNumber numberWithInteger:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
		}
		else
#endif
		{
			[tmpDict setObject:[NSNumber numberWithInteger:_underlineStyle] forKey:(id)kCTUnderlineStyleAttributeName];
		}
		
		// we could set an underline color as well if we wanted, but not supported by HTML
		//      [attributes setObject:(id)[DTImage redColor].CGColor forKey:(id)kCTUnderlineColorAttributeName];
	}
	
	if (_textColor)
	{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			[tmpDict setObject:_textColor forKey:NSForegroundColorAttributeName];
		}
		else
#endif
		{
			[tmpDict setObject:(id)[_textColor CGColor] forKey:(id)kCTForegroundColorAttributeName];
		}
	}
	
	if (_backgroundColor)
	{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			[tmpDict setObject:_backgroundColor forKey:NSBackgroundColorAttributeName];
		}
		else
#endif
		{
			[tmpDict setObject:(id)[_backgroundColor CGColor] forKey:DTBackgroundColorAttribute];
		}
	}
	
	if (_superscriptStyle)
	{
		[tmpDict setObject:(id)[NSNumber numberWithInteger:_superscriptStyle] forKey:(id)kCTSuperscriptAttributeName];
	}
	
	// add paragraph style
	if (_paragraphStyle)
	{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			NSParagraphStyle *style = [self.paragraphStyle NSParagraphStyle];
			[tmpDict setObject:style forKey:NSParagraphStyleAttributeName];
		}
		else
#endif
		{
			CTParagraphStyleRef newParagraphStyle = [self.paragraphStyle createCTParagraphStyle];
			[tmpDict setObject:CFBridgingRelease(newParagraphStyle) forKey:(id)kCTParagraphStyleAttributeName];
		}
	}
	
	// add shadow array if applicable
	if (_shadows)
	{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			// only a single shadow supported
			NSDictionary *firstShadow = [_shadows objectAtIndex:0];
			
			NSShadow *shadow = [[NSShadow alloc] init];
			shadow.shadowOffset = [[firstShadow objectForKey:@"Offset"] CGSizeValue];
			shadow.shadowColor = [firstShadow objectForKey:@"Color"];
			shadow.shadowBlurRadius = [[firstShadow objectForKey:@"Blur"] floatValue];
			[tmpDict setObject:shadow forKey:NSShadowAttributeName];
		}
		else
#endif
		{
			[tmpDict setObject:_shadows forKey:DTShadowsAttribute];
		}
	}
	
	// add tag for PRE so that we can omit changing this font if we override fonts
	if (_preserveNewlines)
	{
		[tmpDict setObject:[NSNumber numberWithBool:YES] forKey:DTPreserveNewlinesAttribute];
	}
	
	if (_headerLevel)
	{
		[tmpDict setObject:[NSNumber numberWithInteger:_headerLevel] forKey:DTHeaderLevelAttribute];
	}
	
	if (_paragraphStyle.textLists)
	{
		[tmpDict setObject:_paragraphStyle.textLists forKey:DTTextListsAttribute];
	}
	
	if (_paragraphStyle.textBlocks)
	{
		[tmpDict setObject:_paragraphStyle.textBlocks forKey:DTTextBlocksAttribute];
	}
	return tmpDict;
}

/*
- (void)appendToAttributedString:(NSMutableAttributedString *)attributedString
{
	if (_displayStyle == DTHTMLElementDisplayStyleNone || _didOutput)
	{
		return;
	}
	
	NSDictionary *attributes = [self attributesDictionary];
	
	if (_textAttachment)
	{
		// ignore children, use unicode object placeholder
		NSMutableAttributedString *tmpString = [[NSMutableAttributedString alloc] initWithString:UNICODE_OBJECT_PLACEHOLDER attributes:attributes];
		[attributedString appendAttributedString:tmpString];
	}
	else
	{
		for (id oneChild in self.childNodes)
		{
			// the string for this single child
			NSAttributedString *tmpString = nil;
			
			if ([oneChild isKindOfClass:[DTHTMLParserTextNode class]])
			{
				[attributedString appendAttributedString:tmpString];
			}
			else
			{
				NSAttributedString *tmpString = [oneChild attributedString];
				[attributedString appendAttributedString:tmpString];
//				
//				if ([[oneChild name] isEqualToString:@"br"])
//				{
//					[attributedString appendString:UNICODE_LINE_FEED];
//				}
//				
//				// should be a normal node
//				[oneChild appendToAttributedString:attributedString];
			}
		}
	}
	
	if (_displayStyle != DTHTMLElementDisplayStyleInline)
	{
		if (![self.name isEqualToString:@"body"] && ![self.name isEqualToString:@"html"])
		{
			[attributedString appendString:@"\n"];
		}
	}
	
	_didOutput = YES;
}
 */

- (BOOL)needsOutput
{
	if ([self.childNodes count])
	{
		for (DTHTMLElement *oneChild in self.childNodes)
		{
			if (!oneChild.didOutput)
			{
				return YES;
			}
		}
		
		return NO;
	}
	
	return YES;
}

- (NSAttributedString *)attributedString
{
	if (_displayStyle == DTHTMLElementDisplayStyleNone || _didOutput)
	{
		return nil;
	}
	
	NSDictionary *attributes = [self attributesDictionary];
	
	NSMutableAttributedString *tmpString;
	
	if (_textAttachment)
	{
		// ignore text, use unicode object placeholder
		tmpString = [[NSMutableAttributedString alloc] initWithString:UNICODE_OBJECT_PLACEHOLDER attributes:attributes];
	}
	else
	{
		// walk through children
		tmpString = [[NSMutableAttributedString alloc] init];
		
		DTHTMLElement *previousChild = nil;
		
		for (DTHTMLElement *oneChild in self.childNodes)
		{
			// if previous node was inline and this child is block then we need a newline
			if (previousChild && previousChild.displayStyle == DTHTMLElementDisplayStyleInline)
			{
				if (oneChild.displayStyle == DTHTMLElementDisplayStyleBlock)
				{
					// trim off whitespace suffix
					while ([[tmpString string] hasSuffixCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]])
					{
						[tmpString deleteCharactersInRange:NSMakeRange([tmpString length]-1, 1)];
					}

					// paragraph break
					[tmpString appendString:@"\n"];
				}
			}
			
			NSAttributedString *nodeString = [oneChild attributedString];
			
			if (nodeString)
			{
				if (!oneChild.containsAppleConvertedSpace)
				{
					// we already have a white space in the string so far
					if ([[tmpString string] hasSuffixCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]])
					{
						while ([[nodeString string] hasPrefix:@" "])
						{
							nodeString = [nodeString attributedSubstringFromRange:NSMakeRange(1, [nodeString length]-1)];
						}
					}
				}
				
				[tmpString appendAttributedString:nodeString];
			}
			
			previousChild = oneChild;
		}
	}

	// block-level elements get space trimmed and a newline
	if (_displayStyle != DTHTMLElementDisplayStyleInline)
	{
		// trim off whitespace prefix
		while ([[tmpString string] hasPrefix:@" "])
		{
			[tmpString deleteCharactersInRange:NSMakeRange(0, 1)];
		}

		// trim off whitespace suffix
		while ([[tmpString string] hasSuffix:@" "])
		{
			[tmpString deleteCharactersInRange:NSMakeRange([tmpString length]-1, 1)];
		}
		
		if (![self.name isEqualToString:@"html"] && ![self.name isEqualToString:@"body"])
		{
			if (![[tmpString string] hasSuffix:@"\n"])
			{
				[tmpString appendString:@"\n"];
			}
		}
	}
	
	// make sure the last sub-paragraph of this has no less than the specified paragraph spacing of this element
	// e.g. last LI needs to inherit the margin-after of the UL
	if (self.displayStyle == DTHTMLElementDisplayStyleBlock)
	{
		NSRange paragraphRange = [[tmpString string] rangeOfParagraphAtIndex:[tmpString length]-1];
		
		
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_5_1
		if (___useiOS6Attributes)
		{
			NSParagraphStyle *paraStyle = [tmpString attribute:NSParagraphStyleAttributeName atIndex:paragraphRange.location effectiveRange:NULL];
			
			DTCoreTextParagraphStyle *paragraphStyle = [DTCoreTextParagraphStyle paragraphStyleWithNSParagraphStyle:paraStyle];
			
			if (paragraphStyle.paragraphSpacing < self.paragraphStyle.paragraphSpacing)
			{
				paragraphStyle.paragraphSpacing = self.paragraphStyle.paragraphSpacing;
				
				// make new paragraph style
				NSParagraphStyle *newParaStyle = [paragraphStyle NSParagraphStyle];
				
				// remove old (works around iOS 4.3 leak)
				[tmpString removeAttribute:NSParagraphStyleAttributeName range:paragraphRange];
				
				// set new
				[tmpString addAttribute:NSParagraphStyleAttributeName value:newParaStyle range:paragraphRange];
			}
		}
		else
#endif
		{
			CTParagraphStyleRef paraStyle = (__bridge CTParagraphStyleRef)[tmpString attribute:(id)kCTParagraphStyleAttributeName atIndex:paragraphRange.location effectiveRange:NULL];
			
			DTCoreTextParagraphStyle *paragraphStyle = [DTCoreTextParagraphStyle paragraphStyleWithCTParagraphStyle:paraStyle];
			
			if (paragraphStyle.paragraphSpacing < self.paragraphStyle.paragraphSpacing)
			{
				paragraphStyle.paragraphSpacing = self.paragraphStyle.paragraphSpacing;
				
				// make new paragraph style
				CTParagraphStyleRef newParaStyle = [paragraphStyle createCTParagraphStyle];
				
				// remove old (works around iOS 4.3 leak)
				[tmpString removeAttribute:(id)kCTParagraphStyleAttributeName range:paragraphRange];
				
				// set new
				[tmpString addAttribute:(id)kCTParagraphStyleAttributeName value:(__bridge_transfer id)newParaStyle range:paragraphRange];
			}
		}
	}
		
	return tmpString;
}

- (DTHTMLElement *)parentElement
{
	return (DTHTMLElement *)self.parentNode;
}

- (BOOL)containedInBlock
{
	id element = self;
	
	while (element && ![[element name] isEqualToString:@"body"])
	{
		if ([element displayStyle] == DTHTMLElementDisplayStyleBlock)
		{
			return YES;
		}
		
		element = [element parentNode];
	}
	
	return NO;
}

- (void)applyStyleDictionary:(NSDictionary *)styles
{
	if (![styles count])
	{
		return;
	}
	
	// keep that for later lookup
	_styles = styles;
	
	// register pseudo-selector contents
	self.beforeContent = [[_styles objectForKey:@"before:content"] stringByDecodingCSSContentAttribute];
	
	NSString *fontSize = [styles objectForKey:@"font-size"];
	if (fontSize)
	{
		// absolute sizes based on 12.0 CoreText default size, Safari has 16.0
		
		if ([fontSize isEqualToString:@"smaller"])
		{
			_fontDescriptor.pointSize /= 1.2f;
		}
		else if ([fontSize isEqualToString:@"larger"])
		{
			_fontDescriptor.pointSize *= 1.2f;
		}
		else if ([fontSize isEqualToString:@"xx-small"])
		{
			_fontDescriptor.pointSize = 9.0f/1.3333f * _textScale;
		}
		else if ([fontSize isEqualToString:@"x-small"])
		{
			_fontDescriptor.pointSize = 10.0f/1.3333f * _textScale;
		}
		else if ([fontSize isEqualToString:@"small"])
		{
			_fontDescriptor.pointSize = 13.0f/1.3333f * _textScale;
		}
		else if ([fontSize isEqualToString:@"medium"])
		{
			_fontDescriptor.pointSize = 16.0f/1.3333f * _textScale;
		}
		else if ([fontSize isEqualToString:@"large"])
		{
			_fontDescriptor.pointSize = 22.0f/1.3333f * _textScale;
		}
		else if ([fontSize isEqualToString:@"x-large"])
		{
			_fontDescriptor.pointSize = 24.0f/1.3333f * _textScale;
		}
		else if ([fontSize isEqualToString:@"xx-large"])
		{
			_fontDescriptor.pointSize = 37.0f/1.3333f * _textScale;
		}
		else if ([fontSize isEqualToString:@"inherit"])
		{
			_fontDescriptor.pointSize = _parent.fontDescriptor.pointSize;
		}
		else
		{
			CGFloat fontSizeValue = [fontSize pixelSizeOfCSSMeasureRelativeToCurrentTextSize:_fontDescriptor.pointSize textScale:_textScale];
			_fontDescriptor.pointSize = fontSizeValue;
		}
	}
	
	NSString *color = [styles objectForKey:@"color"];
	if (color)
	{
		self.textColor = [DTColor colorWithHTMLName:color];       
	}
	
	NSString *bgColor = [styles objectForKey:@"background-color"];
	if (bgColor)
	{
		self.backgroundColor = [DTColor colorWithHTMLName:bgColor];       
	}
	
	NSString *floatString = [styles objectForKey:@"float"];
	
	if (floatString)
	{
		if ([floatString isEqualToString:@"left"])
		{
			_floatStyle = DTHTMLElementFloatStyleLeft;
		}
		else if ([floatString isEqualToString:@"right"])
		{
			_floatStyle = DTHTMLElementFloatStyleRight;
		}
		else if ([floatString isEqualToString:@"none"])
		{
			_floatStyle = DTHTMLElementFloatStyleNone;
		}
	}
	
	NSString *fontFamily = [[styles objectForKey:@"font-family"] stringByTrimmingCharactersInSet:[NSCharacterSet quoteCharacterSet]];
	
	if (fontFamily)
	{
		NSString *lowercaseFontFamily = [fontFamily lowercaseString];
		
		if ([lowercaseFontFamily rangeOfString:@"geneva"].length)
		{
			_fontDescriptor.fontFamily = @"Helvetica";
		}
		else if ([lowercaseFontFamily rangeOfString:@"cursive"].length)
		{
			_fontDescriptor.stylisticClass = kCTFontScriptsClass;
			_fontDescriptor.fontFamily = nil;
		}
		else if ([lowercaseFontFamily rangeOfString:@"sans-serif"].length)
		{
			// too many matches (24)
			// fontDescriptor.stylisticClass = kCTFontSansSerifClass;
			_fontDescriptor.fontFamily = @"Helvetica";
		}
		else if ([lowercaseFontFamily rangeOfString:@"serif"].length)
		{
			// kCTFontTransitionalSerifsClass = Baskerville
			// kCTFontClarendonSerifsClass = American Typewriter
			// kCTFontSlabSerifsClass = Courier New
			// 
			// strangely none of the classes yields Times
			_fontDescriptor.fontFamily = @"Times New Roman";
		}
		else if ([lowercaseFontFamily rangeOfString:@"fantasy"].length)
		{
			_fontDescriptor.fontFamily = @"Papyrus"; // only available on iPad
		}
		else if ([lowercaseFontFamily rangeOfString:@"monospace"].length) 
		{
			_fontDescriptor.monospaceTrait = YES;
			_fontDescriptor.fontFamily = @"Courier";
		}
		else if ([lowercaseFontFamily rangeOfString:@"times"].length) 
		{
			_fontDescriptor.fontFamily = @"Times New Roman";
		}
		else
		{
			// probably custom font registered in info.plist
			_fontDescriptor.fontFamily = fontFamily;
		}
	}
	
	NSString *fontStyle = [[styles objectForKey:@"font-style"] lowercaseString];
	if (fontStyle)
	{
		if ([fontStyle isEqualToString:@"normal"])
		{
			_fontDescriptor.italicTrait = NO;
		}
		else if ([fontStyle isEqualToString:@"italic"] || [fontStyle isEqualToString:@"oblique"])
		{
			_fontDescriptor.italicTrait = YES;
		}
		else if ([fontStyle isEqualToString:@"inherit"])
		{
			// nothing to do
		}
	}
	
	NSString *fontWeight = [[styles objectForKey:@"font-weight"] lowercaseString];
	if (fontWeight)
	{
		if ([fontWeight isEqualToString:@"normal"])
		{
			_fontDescriptor.boldTrait = NO;
		}
		else if ([fontWeight isEqualToString:@"bold"])
		{
			_fontDescriptor.boldTrait = YES;
		}
		else if ([fontWeight isEqualToString:@"bolder"])
		{
			_fontDescriptor.boldTrait = YES;
		}
		else if ([fontWeight isEqualToString:@"lighter"])
		{
			_fontDescriptor.boldTrait = NO;
		}
		else 
		{
			// can be 100 - 900
			
			NSInteger value = [fontWeight intValue];
			
			if (value<=600)
			{
				_fontDescriptor.boldTrait = NO;
			}
			else 
			{
				_fontDescriptor.boldTrait = YES;
			}
		}
	}
	
	
	NSString *decoration = [[styles objectForKey:@"text-decoration"] lowercaseString];
	if (decoration)
	{
		if ([decoration isEqualToString:@"underline"])
		{
			self.underlineStyle = kCTUnderlineStyleSingle;
		}
		else if ([decoration isEqualToString:@"line-through"])
		{
			self.strikeOut = YES;
		}
		else if ([decoration isEqualToString:@"none"])
		{
			// remove all
			self.underlineStyle = kCTUnderlineStyleNone;
			self.strikeOut = NO;
		}
		else if ([decoration isEqualToString:@"overline"])
		{
			//TODO: add support for overline decoration
		}
		else if ([decoration isEqualToString:@"blink"])
		{
			//TODO: add support for blink decoration
		}
		else if ([decoration isEqualToString:@"inherit"])
		{
			// nothing to do
		}
	}
	
	NSString *alignment = [[styles objectForKey:@"text-align"] lowercaseString];
	if (alignment)
	{
		if ([alignment isEqualToString:@"left"])
		{
			self.paragraphStyle.alignment = kCTLeftTextAlignment;
		}
		else if ([alignment isEqualToString:@"right"])
		{
			self.paragraphStyle.alignment = kCTRightTextAlignment;
		}
		else if ([alignment isEqualToString:@"center"])
		{
			self.paragraphStyle.alignment = kCTCenterTextAlignment;
		}
		else if ([alignment isEqualToString:@"justify"])
		{
			self.paragraphStyle.alignment = kCTJustifiedTextAlignment;
		}
		else if ([alignment isEqualToString:@"inherit"])
		{
			// nothing to do
		}
	}
	
	NSString *verticalAlignment = [[styles objectForKey:@"vertical-align"] lowercaseString];
	if (verticalAlignment)
	{
		if ([verticalAlignment isEqualToString:@"sub"])
		{
			self.superscriptStyle = -1;
		}
		else if ([verticalAlignment isEqualToString:@"super"])
		{
			self.superscriptStyle = +1;
		}
		else if ([verticalAlignment isEqualToString:@"baseline"])
		{
			self.superscriptStyle = 0;
		}
		else if ([verticalAlignment isEqualToString:@"inherit"])
		{
			// nothing to do
		}
		else if ([verticalAlignment isEqualToString:@"text-top"])
		{
			_textAttachmentAlignment = DTTextAttachmentVerticalAlignmentTop;
		}
		else if ([verticalAlignment isEqualToString:@"middle"])
		{
			_textAttachmentAlignment = DTTextAttachmentVerticalAlignmentCenter;
		}
		else if ([verticalAlignment isEqualToString:@"text-bottom"])
		{
			_textAttachmentAlignment = DTTextAttachmentVerticalAlignmentBottom;
		}
		else if ([verticalAlignment isEqualToString:@"baseline"])
		{
			_textAttachmentAlignment = DTTextAttachmentVerticalAlignmentBaseline;
		}
	}
	
	// if there is a text attachment we transfer the aligment we got
	_textAttachment.verticalAlignment = _textAttachmentAlignment;
	
	NSString *shadow = [styles objectForKey:@"text-shadow"];
	if (shadow)
	{
		self.shadows = [shadow arrayOfCSSShadowsWithCurrentTextSize:_fontDescriptor.pointSize currentColor:_textColor];
	}
	
	NSString *lineHeight = [[styles objectForKey:@"line-height"] lowercaseString];
	if (lineHeight)
	{
		if ([lineHeight isEqualToString:@"normal"])
		{
			self.paragraphStyle.lineHeightMultiple = 0.0; // default
			self.paragraphStyle.minimumLineHeight = 0.0; // default
			self.paragraphStyle.maximumLineHeight = 0.0; // default
		}
		else if ([lineHeight isEqualToString:@"inherit"])
		{
			// no op, we already inherited it
		}
		else if ([lineHeight isNumeric])
		{
			self.paragraphStyle.lineHeightMultiple = [lineHeight floatValue];
		}
		else // interpret as length
		{
			CGFloat lineHeightValue = [lineHeight pixelSizeOfCSSMeasureRelativeToCurrentTextSize:_fontDescriptor.pointSize textScale:_textScale];
			self.paragraphStyle.minimumLineHeight = lineHeightValue;
			self.paragraphStyle.maximumLineHeight = lineHeightValue;
		}
	}
	
	NSString *marginBottom = [styles objectForKey:@"margin-bottom"];
	if (marginBottom) 
	{
		CGFloat marginBottomValue = [marginBottom pixelSizeOfCSSMeasureRelativeToCurrentTextSize:_fontDescriptor.pointSize textScale:_textScale];
		self.paragraphStyle.paragraphSpacing = marginBottomValue;

	}
	else
	{
		NSString *webkitMarginAfter = [styles objectForKey:@"-webkit-margin-after"];
		if (webkitMarginAfter) 
		{
			self.paragraphStyle.paragraphSpacing = [webkitMarginAfter pixelSizeOfCSSMeasureRelativeToCurrentTextSize:_fontDescriptor.pointSize textScale:_textScale];
		}
	}
	
	NSString *marginLeft = [styles objectForKey:@"margin-left"];
	if (marginLeft)
	{
		self.paragraphStyle.headIndent = [marginLeft pixelSizeOfCSSMeasureRelativeToCurrentTextSize:_fontDescriptor.pointSize textScale:_textScale];
		self.paragraphStyle.firstLineHeadIndent = self.paragraphStyle.headIndent;
	}

	NSString *marginRight = [styles objectForKey:@"margin-right"];
	if (marginRight)
	{
		self.paragraphStyle.tailIndent = -[marginRight pixelSizeOfCSSMeasureRelativeToCurrentTextSize:_fontDescriptor.pointSize textScale:_textScale];
	}
	
	NSString *fontVariantStr = [[styles objectForKey:@"font-variant"] lowercaseString];
	if (fontVariantStr)
	{
		if ([fontVariantStr isEqualToString:@"small-caps"])
		{
			_fontVariant = DTHTMLElementFontVariantSmallCaps;
		}
		else if ([fontVariantStr isEqualToString:@"inherit"])
		{
			_fontVariant = DTHTMLElementFontVariantInherit;
		}
		else
		{
			_fontVariant = DTHTMLElementFontVariantNormal;
		}
	}
	
	NSString *widthString = [styles objectForKey:@"width"];
	if (widthString && ![widthString isEqualToString:@"auto"])
	{
		_size.width = [widthString pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
	}
	
	NSString *heightString = [styles objectForKey:@"height"];
	if (heightString && ![heightString isEqualToString:@"auto"])
	{
		_size.height = [heightString pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
	}
	
	// if this has an attachment set its size too
	_textAttachment.displaySize = _size;
	
	NSString *whitespaceString = [styles objectForKey:@"white-space"];
	if ([whitespaceString hasPrefix:@"pre"])
	{
		_preserveNewlines = YES;
	}
	else
	{
		_preserveNewlines = NO;
	}
	
	NSString *displayString = [styles objectForKey:@"display"];
	if (displayString)
	{
		if ([displayString isEqualToString:@"none"])
		{
			_displayStyle = DTHTMLElementDisplayStyleNone;
		}
		else if ([displayString isEqualToString:@"block"])
		{
			_displayStyle = DTHTMLElementDisplayStyleBlock;
		}
		else if ([displayString isEqualToString:@"inline"])
		{
			_displayStyle = DTHTMLElementDisplayStyleInline;
		}
		else if ([displayString isEqualToString:@"list-item"])
		{
			_displayStyle = DTHTMLElementDisplayStyleListItem;
		}
		else if ([displayString isEqualToString:@"table"])
		{
			_displayStyle = DTHTMLElementDisplayStyleTable;
		}
		else if ([verticalAlignment isEqualToString:@"inherit"])
		{
			// nothing to do
		}
	}
	
	DTEdgeInsets padding = {0,0,0,0};
	
	// webkit default value
	NSString *webkitPaddingStart = [styles objectForKey:@"-webkit-padding-start"];
	
	if (webkitPaddingStart)
	{
		self.paragraphStyle.listIndent = [webkitPaddingStart pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
	}
	
	BOOL needsTextBlock = (_backgroundColor!=nil);
	
	NSString *paddingString = [styles objectForKey:@"padding"];
	
	if (paddingString)
	{
		// maybe it's using the short style
		NSArray *parts = [paddingString componentsSeparatedByString:@" "];
		
		if ([parts count] == 4)
		{
			padding.top = [[parts objectAtIndex:0] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding.right = [[parts objectAtIndex:1] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding.bottom = [[parts objectAtIndex:2] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding.left = [[parts objectAtIndex:3] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
		}
		else if ([parts count] == 3)
		{
			padding.top = [[parts objectAtIndex:0] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding.right = [[parts objectAtIndex:1] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding.bottom = [[parts objectAtIndex:2] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding.left = padding.right;
		}
		else if ([parts count] == 2)
		{
			padding.top = [[parts objectAtIndex:0] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding.right = [[parts objectAtIndex:1] pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding.bottom = padding.top;
			padding.left = padding.right;
		}
		else 
		{
			CGFloat paddingAmount = [paddingString pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			padding = DTEdgeInsetsMake(paddingAmount, paddingAmount, paddingAmount, paddingAmount);
		}
		
		// left padding overrides webkit list indent
		self.paragraphStyle.listIndent = padding.left;
		
		needsTextBlock = YES;
	}
	else
	{
		paddingString = [styles objectForKey:@"padding-left"];
		
		if (paddingString)
		{
			padding.left = [paddingString pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			needsTextBlock = YES;
			
			// left padding overrides webkit list indent
			self.paragraphStyle.listIndent = padding.left;
		}
		
		paddingString = [styles objectForKey:@"padding-top"];
		
		if (paddingString)
		{
			padding.top = [paddingString pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			needsTextBlock = YES;
		}
		
		paddingString = [styles objectForKey:@"padding-right"];
		
		if (paddingString)
		{
			padding.right = [paddingString pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			needsTextBlock = YES;
		}
		
		paddingString = [styles objectForKey:@"padding-bottom"];
		
		if (paddingString)
		{
			padding.bottom = [paddingString pixelSizeOfCSSMeasureRelativeToCurrentTextSize:self.fontDescriptor.pointSize textScale:_textScale];
			needsTextBlock = YES;
		}
	}
	
	if (_displayStyle == DTHTMLElementDisplayStyleBlock)
	{
		if (needsTextBlock)
		{
			// need a block
			DTTextBlock *newBlock = [[DTTextBlock alloc] init];
			
			newBlock.padding = padding;
			
			// transfer background color to block
			newBlock.backgroundColor = _backgroundColor;
			_backgroundColor = nil;
			
			NSArray *newBlocks = [self.paragraphStyle.textBlocks mutableCopy];
			
			if (!newBlocks)
			{
				// need an array, this is the first block
				newBlocks = [NSArray arrayWithObject:newBlock];
			}
			
			self.paragraphStyle.textBlocks = newBlocks;
		}
	}
}

- (NSDictionary *)styles
{
	return _styles;
}

- (void)parseStyleString:(NSString *)styleString
{
	NSDictionary *styles = [styleString dictionaryOfCSSStyles];
	[self applyStyleDictionary:styles];
}

- (void)addAdditionalAttribute:(id)attribute forKey:(id)key
{
	if (!_additionalAttributes)
	{
		_additionalAttributes = [[NSMutableDictionary alloc] init];
	}
	
	[_additionalAttributes setObject:attribute forKey:key];
}

- (NSString *)attributeForKey:(NSString *)key
{
	return [_attributes objectForKey:key];
}

#pragma mark Calulcating Properties

- (id)valueForKeyPathWithInheritance:(NSString *)keyPath
{
	
	
	id value = [self valueForKeyPath:keyPath];
	
	// if property is not set we also go to parent
	if (!value && _parent)
	{
		return [_parent valueForKeyPathWithInheritance:keyPath];
	}
	
	// enum properties have 0 for inherit
	if ([value isKindOfClass:[NSNumber class]])
	{
		NSNumber *number = value;
		
		if (([number integerValue]==0) && _parent)
		{
			return [_parent valueForKeyPathWithInheritance:keyPath];
		}
	}
	
	// string properties have 'inherit' for inheriting
	if ([value isKindOfClass:[NSString class]])
	{
		NSString *string = value;
		
		if ([string isEqualToString:@"inherit"] && _parent)
		{
			return [_parent valueForKeyPathWithInheritance:keyPath];
		}
	}
	
	// obviously not inherited
	return value;
}


- (DTCSSListStyle *)calculatedListStyle
{
	DTCSSListStyle *style = [[DTCSSListStyle alloc] init];
	
	id calcType = [self valueForKeyPathWithInheritance:@"listStyle.type"];
	id calcPos = [self valueForKeyPathWithInheritance:@"listStyle.position"];
	id calcImage = [self valueForKeyPathWithInheritance:@"listStyle.imageName"];
	
	style.type = (DTCSSListStyleType)[calcType integerValue];
	style.position = (DTCSSListStylePosition)[calcPos integerValue];
	style.imageName = calcImage;
	
	return style;
}

#pragma mark - Inheriting Attributes

- (void)inheritAttributesFromElement:(DTHTMLElement *)element
{
	_fontDescriptor = [element.fontDescriptor copy];
	_paragraphStyle = [element.paragraphStyle copy];

	_fontVariant = element.fontVariant;
	_underlineStyle = element.underlineStyle;
	_strikeOut = element.strikeOut;
	_superscriptStyle = element.superscriptStyle;
	
	_shadows = [element.shadows copy];

	_link = [element.link copy];
	_anchorName = [element.anchorName copy];
	_linkGUID = element.linkGUID;
	
	_textColor = element.textColor;
	_isColorInherited = YES;
	
	_preserveNewlines = element.preserveNewlines;
	_textScale = element.textScale;
	
	// only inherit background-color from inline elements
	if (element.displayStyle == DTHTMLElementDisplayStyleInline)
	{
		self.backgroundColor = element.backgroundColor;
	}
	
	_containsAppleConvertedSpace = element.containsAppleConvertedSpace;
}

- (void)interpretAttributes
{
	if (!_attributes)
	{
		// nothing to interpret
		return;
	}
	
	// transfer Apple Converted Space tag
	if ([[self attributeForKey:@"class"] isEqualToString:@"Apple-converted-space"])
	{
		_containsAppleConvertedSpace = YES;
	}
	
	// detect writing direction if set
	NSString *directionStr = [self attributeForKey:@"dir"];
	
	if (directionStr)
	{
		NSAssert(_paragraphStyle, @"Found dir attribute, but missing paragraph style on element");
		
		if ([directionStr isEqualToString:@"rtl"])
		{
			_paragraphStyle.baseWritingDirection = NSWritingDirectionRightToLeft;
		}
		else if ([directionStr isEqualToString:@"ltr"])
		{
			_paragraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
		}
		else if ([directionStr isEqualToString:@"auto"])
		{
			_paragraphStyle.baseWritingDirection = NSWritingDirectionNatural; // that's also default
		}
		else
		{
			// other values are invalid and will be ignored
		}
	}
}

#pragma mark Properties

- (void)setTextColor:(DTColor *)textColor
{
	if (_textColor != textColor)
	{
		
		_textColor = textColor;
		_isColorInherited = NO;
	}
}

- (DTHTMLElementFontVariant)fontVariant
{
	if (_fontVariant == DTHTMLElementFontVariantInherit)
	{
		if (_parent)
		{
			return _parent.fontVariant;
		}
		
		return DTHTMLElementFontVariantNormal;
	}
	
	return _fontVariant;
}

- (void)setAttributes:(NSDictionary *)attributes
{
	[super setAttributes:[attributes copy]];
	
	// decode size contained in attributes, might be overridden later by CSS size
	_size = CGSizeMake([[self attributeForKey:@"width"] floatValue], [[self attributeForKey:@"height"] floatValue]);
}

- (void)setTextAttachment:(DTTextAttachment *)textAttachment
{
	textAttachment.verticalAlignment = _textAttachmentAlignment;
	_textAttachment = textAttachment;
	
	// transfer link GUID
	_textAttachment.hyperLinkGUID = _linkGUID;
	
	// transfer size
	_textAttachment.displaySize = _size;
}

- (void)setLink:(NSURL *)link
{
	_linkGUID = [NSString stringWithUUID];
	_link = [link copy];
	
	if (_textAttachment)
	{
		_textAttachment.hyperLinkGUID = _linkGUID;
	}
}

@synthesize fontDescriptor = _fontDescriptor;
@synthesize paragraphStyle = _paragraphStyle;
@synthesize textColor = _textColor;
@synthesize backgroundColor = _backgroundColor;
@synthesize beforeContent = _beforeContent;
@synthesize link = _link;
@synthesize anchorName = _anchorName;
@synthesize underlineStyle = _underlineStyle;
@synthesize textAttachment = _textAttachment;
@synthesize strikeOut = _strikeOut;
@synthesize superscriptStyle = _superscriptStyle;
@synthesize headerLevel = _headerLevel;
@synthesize shadows = _shadows;
@synthesize floatStyle = _floatStyle;
@synthesize isColorInherited = _isColorInherited;
@synthesize preserveNewlines = _preserveNewlines;
@synthesize displayStyle = _displayStyle;
@synthesize fontVariant = _fontVariant;
@synthesize textScale = _textScale;
@synthesize size = _size;
@synthesize linkGUID = _linkGUID;
@synthesize containsAppleConvertedSpace = _containsAppleConvertedSpace;

@end


