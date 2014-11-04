require 'rubygems'
require 'stanford-core-nlp'
require 'wordnet'
require 'linguistics'
require 'socket'
require 'uri'

Linguistics.use(:en)

def get_frequency_rankings
  file = File.open('frequency_list.txt', 'r')
  frequency_rankings = {}
  file.each_line do |line|
    ranking, word, count = line.split(' ')
    frequency_rankings[word.downcase] = ranking.to_i
  end
  return frequency_rankings
end

def elegantize(word, target_poss, frequency_rankings)
  lex = WordNet::Lexicon.new
  most_elegant_synonym = word.to_s

  synsets = lex.lookup_synsets(word)
  synsets.each do |synset|
    if target_poss.include?(synset.pos)
      synset.words.each do |synonym|
        # puts "current most_elegant_synonym is #{most_elegant_synonym}"
        # puts "current synonym is #{synonym.to_s}"

        if frequency_rankings[synonym.to_s].to_i > frequency_rankings[most_elegant_synonym].to_i
          puts "replacing #{most_elegant_synonym} with #{synonym.to_s}"
          most_elegant_synonym = synonym.to_s
        end
      end
    end
  end

  return most_elegant_synonym
end

def pos_based_verb(verb, pos)
  conjugated_verb = verb
  if ['VBD', 'VBG', 'VBN', 'VBP', 'VBZ'].include?(pos)
    conjugated_verb =
      case pos
      when 'VBD'
        verb.en.past_tense
      when 'VBG'
        verb.en.present_participle
      when 'VBN'
        verb.en.past_participle
      when 'VBP'
        verb.en.present_tense
      when 'VBZ'
        verb.en.conjugate(:present, :third_person_singular)
      else
        verb
      end
  end

  return conjugated_verb
end

###############################################################################################
# the POS's we care to profundify & elegantize
key_poss = {
  'JJ' => ['a', 's'],
  'JJR' => ['a', 's'],
  'JJS' => ['a', 's'],
  'NN' => ['n'],
  'NNS' => ['n'],
  'RB' => ['r'],
  'RBR' => ['r'],
  'RBS' => ['r'],
  'VB' => ['v'],
  'VBD' => ['v'],
  'VBG' => ['v'],
  'VBN' => ['v'],
  'VBP' => ['v'],
  'VBZ' => ['v']
}

keep_words = ['be', 'have', 'time', 'life', 'day', 'night', 'get']
punctuations = ["'", ',', '.', ':', ';']
###############################################################################################
# text = <<eos
#   Angela met Nicolas on January 25th in the United States
#   to talk about a new plan. Sarkozy looked happy, but Merkel was sad.
# eos

# text = <<eos
# RORY: The first week of school is called shopping week. You get to try out as many
# classes as you want before you pick the ones you want to stick with for the semester.
# I picked over fifty classes I'm gonna try out, plus another ten I'm gonna squeeze
# in if I have the time. They all sound completely amazing. I stayed up all night
# reading the class subscriptions over and over.

# LORELAI: I hope you know that if you weren't so beautiful, you would've gotten the crap
# kicked out of you every day of your life.
# eos

frequency_rankings = get_frequency_rankings
pipeline =  StanfordCoreNLP.load(:tokenize, :ssplit, :pos, :lemma, :parse)

server = TCPServer.new('localhost', 9999)
regex = /elegantize\/(.+) HTTP/
while (session = server.accept)
  text = URI.unescape(regex.match(session.gets)[1])
  annotation = StanfordCoreNLP::Annotation.new(text)
  pipeline.annotate(annotation)

  new_text = ""
  lex = WordNet::Lexicon.new

  annotation.get(:sentences).each do |sentence|
    sentence.get(:tokens).each do |token|
      elegant_synonym = token.get(:original_text).to_s

      pos = token.get(:part_of_speech).to_s
      puts " ////////////////////   #{pos}" if elegant_synonym == 'pretty'
      if (key_poss.keys.include?(pos))
        lemma = token.get(:lemma).to_s
        unless keep_words.include?(lemma)
          synonym = elegantize(lemma, key_poss[pos], frequency_rankings)
          if synonym != lemma
            if ['VBD', 'VBG', 'VBN', 'VBP', 'VBZ'].include?(pos)
              synonym = pos_based_verb(synonym, pos)
            end

            elegant_synonym = synonym
          end
        end
      end

      elegant_synonym = 'going to' if elegant_synonym == 'gonna'
      elegant_synonym = 'want to' if elegant_synonym == 'wanna'

      if punctuations.include?(elegant_synonym[0])
        new_text += elegant_synonym # for 've, comma, period etc
      else
        new_text += " " + elegant_synonym
      end
    end
  end

  session.puts new_text
  session.close
end
