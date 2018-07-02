//
//  ViewController.swift
//  ElasticTabStops
//
//  Created by Chris Eidhof on 29.06.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import Cocoa

let text = """
int someDemoCode(	int start,
	int length)
{
	x()	/* try making    */
	print("hello!")	/* this comment  */
	aLongerMethodThatDoesSomethingComplicated()	/* a bit longer  */
	for (i in range(start, length))
	{
		if (isValid(i))
		{
			count++
		}
	}
	return count
}

One	Test	Two	Three
Hello world	This is a test	Two	Three



You can use elastic tabstops with tables and TSV files too

Title	Author	Publisher	Year
Generation X	Douglas Coupland	Abacus	1995
Informagic	Jean-Pierre Petit	John Murray Ltd	1982
The Cyberiad	Stanislaw Lem	Harcourt Publishers Ltd	1985
"""

let text2 = """
hello
	one
	two
		three
	four
five
"""

extension String {
    func split(separator: (Character) -> Bool) -> [NSRange] {
        var result: [NSRange] = []
        var start = startIndex
        let end = endIndex
        while start < end {
            let i = self[start...].index(where: separator) ?? end
            let range = NSRange((start..<i) as Range<Index>, in: self)
            result.append(range)
            start = i == end ? end : index(after: i)
        }
        return result
    }
}

extension NSAttributedString {
    var lines: [NSRange] {
        return string.split(separator: { $0 == "\n" })
    }
    
    func tabs(in range: NSRange) -> Int {
        return (string as NSString).substring(with: range).filter { $0 == "\t" }.count
    }
    
    func cells(in range: NSRange) -> [NSRange] {
        return String(string[Range(range, in: string)!]).split { $0 == "\t" }.map { NSMakeRange($0.location + range.location, $0.length)}
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        guard index >= startIndex && index < endIndex else { return nil }
        return self[index]
    }
}

extension Array where Element: Numeric {
    /// Accumulates the elements, for example:
    ///
    /// `[1, 4, 8, 10]` turns into `[1, 5, 13, 23]`
    func accumulate() -> Array {
        var result: Array = []
        for el in self {
            result.append((result.last ?? 0) + el)
        }
        return result
    }
}

extension NSAttributedString {
    var range: NSRange {
        return NSMakeRange(0, string.count)
    }
}

extension Sequence {
    func mapWithLast<B>(withLast: (_ last: B?, _ element: Element) -> B) -> [B] {
        var result: [B] = []
        for x in self {
            result.append(withLast(result.last, x))
        }
        return result
    }
}

extension NSAttributedString {
    func elastic(prefixTabStopWidth: CGFloat = 20, minSpacing: CGFloat = 5) -> [(NSRange, NSParagraphStyle)] {
        let lines = self.lines
        let widths = lines.map { line in
            cells(in: line).dropLast().map { attributedSubstring(from: $0).size().width }
    	}

        let tabStops: [[CGFloat]] = lines.indices.mapWithLast { previous, i in
            let tabs = self.tabs(in: lines[i])
            var stops = previous ?? []
            
            // No tab stop means a "reset" of the column
            if stops.count > tabs {
                stops.removeLast(stops.count - tabs)
            }
            
            // For each newly started column
            for column in stops.count..<tabs {
                // take the max of all the other cells in this column:
                let columnWidth = widths.suffix(from: i).lazy.map { $0[safe: column] }.prefix(while: { $0 != nil }).map { $0! }.max() ?? 0
                stops.append(columnWidth)
            }
            
            return stops
        }

        return Array(zip(lines, tabStops.map { t in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = t.map { max($0 + minSpacing, prefixTabStopWidth) }.accumulate().map {
                return NSTextTab(textAlignment: .left, location: $0)
            }
            return paragraphStyle
        }))
    }
}


class ViewController: NSViewController, NSTextViewDelegate {
    @IBOutlet var textView: NSTextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let attrStr = NSMutableAttributedString(string: text, attributes: [:])
        for (range, style) in attrStr.elastic() {
            attrStr.setAttributes([.paragraphStyle: style], range: range)
        }
        textView.textStorage?.insert(attrStr, at: 0)
        textView.delegate = self
    }
    
    func textDidChange(_ notification: Notification) {
        textView.textStorage?.removeAttribute(.paragraphStyle, range: textView.attributedString().range)
        for (range, style) in textView.attributedString().elastic() {
            textView.textStorage!.setAttributes([.paragraphStyle: style], range: range)
        }
    }
}

