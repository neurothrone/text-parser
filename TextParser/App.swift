//
//  App.swift
//  TextParser
//
//  Created by Zaid Neurothrone on 2022-12-07.
//

import ArgumentParser
import Foundation
import NaturalLanguage

/*
 When you run the program with the command ./TextParser --help you will see that
 the program is called “analyze” rather than just “app”. Note that this doesn’t
 change the program’s actual name on your filesystem – that still comes from Xcode’s
 project name. The best way to change that is while you copy the project across to
 your main filesystem so that it can be used anywhere, like this:
 
 cp TextParser /usr/local/bin/analyze.
 
 Once you’ve run that copy command, you’ll find the analyze works everywhere on
 your Mac – it’s much more convenient than having to look inside Xcode’s build
 directory each time!
 */

@main
struct App: ParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "analyze",
      abstract: "Analyzes input text using a range of natural language approaches."
    )
  }
  
  @Argument(help: "The text you want to analyze")
  var input: [String]
  
  @Flag(name: .customLong("everything"), help: "Run all functions")
  var runEverything = false
  
  @Flag(name: .shortAndLong, help: "Show detected language.")
  var detectLanguage = false
  
  @Flag(name: .shortAndLong, help: "Prints how positive or negative the input is.")
  var sentimentAnalysis = false
        
  @Flag(name: .shortAndLong, help: "Shows the stem form of each word in the input.")
  var lemmatize = false
        
  @Flag(name: .shortAndLong, help: "Prints alternative words for each word in the input.")
  var alternatives = false
        
  @Flag(name: .shortAndLong, help: "Prints names of people, places, and organizations in the input.")
  var names = false
        
  @Option(name: .shortAndLong, help: "The maximum number of alternatives to suggest")
  var maximumAlternatives = 10
  
  mutating func run() {
    //    print("Hello, World!")
    //    print(CommandLine.arguments)
    //    let text = CommandLine.arguments.dropFirst().joined(separator: " ")
    
    if runEverything {
      detectLanguage = true
      sentimentAnalysis = true
      lemmatize = true
      alternatives = true
      names = true
    }
//    if detectLanguage == false &&
//        sentimentAnalysis == false &&
//        lemmatize == false &&
//        alternatives == false &&
//        names == false {
//      detectLanguage = true
//      sentimentAnalysis = true
//      lemmatize = true
//      alternatives = true
//      names = true
//    }
    
    let text = input.joined(separator: " ")
    print(text)
    
    //MARK: - Detect langauge
    if detectLanguage {
      let language = NLLanguageRecognizer.dominantLanguage(for: text) ?? .undetermined
      
      print()
      print("Detected language: \(language.rawValue)")
    }

    
    //MARK: - Performing semantic analysis
    if sentimentAnalysis {
      let sentiment = sentiment(for: text)
      
      print()
      print("Sentiment analysis: \(sentiment)")
    }

    lazy var lemma = lemmatize(string: text)
    
    if lemmatize {
      print()
      print("Found the following lemma:")
      print("\t", lemma.formatted(.list(type: .and)))
    }
    
    //MARK: - Finding alternate words
    if alternatives {
      print()
      print("Found the following alternatives:")
      
      for word in lemma {
        let embeddings = embeddings(for: word)
        print("\t\(word): ", embeddings.formatted(.list(type: .and)))
      }
    }
    
    //MARK: - Detecting names and languages
    if names {
      print()
      print("Found the following entities:")
      
      let entities = entities(for: text)
      
      for entity in entities {
        print("\t", entity)
      }
    }
  }
  
  func sentiment(for string: String) -> Double {
    let tagger = NLTagger(tagSchemes: [.sentimentScore])
    tagger.string = string
    
    let (sentiment, _) = tagger.tag(at: string.startIndex, unit: .paragraph, scheme: .sentimentScore)
    
    return Double(sentiment?.rawValue ?? "0") ?? .zero
  }
  
  func embeddings(for word: String) -> [String] {
    var results: [String] = []
    
    if let embedding = NLEmbedding.wordEmbedding(for: .english) {
      let similarWords = embedding.neighbors(for: word, maximumCount: maximumAlternatives)
      
      for word in similarWords {
        results.append("\(word.0) has a distance of \(word.1)")
      }
    }
    
    return results
  }
  
  func lemmatize(string: String) -> [String] {
    let tagger = NLTagger(tagSchemes: [.lemma])
    tagger.string = string
    
    var results: [String] = []
    
    tagger.enumerateTags(
      in: string.startIndex..<string.endIndex,
      unit: .word,
      scheme: .lemma
    ) { tag, range in
      let stemForm = tag?.rawValue ?? String(string[range]).trimmingCharacters(in: .whitespaces)
      
      if stemForm.isEmpty == false {
        results.append(stemForm)
      }
      
      return true
    }
    
    return results
  }
  
  func entities(for string: String) -> [String] {
    let tagger = NLTagger(tagSchemes: [.nameType])
    tagger.string = string
    var results: [String] = []
    
    tagger.enumerateTags(
      in: string.startIndex..<string.endIndex,
      unit: .word,
      scheme: .nameType,
      options: .joinNames
    ) { tag, range in
      
      guard let tag = tag else { return true }
      
      let match = String(string[range])
      
      switch tag {
      case .organizationName:
        results.append("Organization: \(match)")
      case .personalName:
        results.append("Person: \(match)")
      case .placeName:
        results.append("Place: \(match)")
      default:
        break
      }
      
      return true
    }
    
    return results
  }
}
