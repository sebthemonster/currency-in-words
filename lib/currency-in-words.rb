# encoding: utf-8
module CurrencyInWords
  ActionView::Helpers::NumberHelper.class_eval do

    DEFAULT_CURRENCY_IN_WORDS_VALUES = {:currencies=>{:default=>{:unit=>{:one=>'dollar',:many=>'dollars'},
                                        :decimal=>{:one=>'cent',:many=>'cents'}}},
                                        :connector=>', ',:format=>'%n',:negative_format=>'minus %n'}

    # Formats a +number+ into a currency string (e.g., 'one hundred dollars'). You can customize the 
    # format in the +options+ hash.
    #
    # === Options for all locales
    # * <tt>:locale</tt> - Sets the locale to be used for formatting (defaults to current locale).
    # * <tt>:currency</tt> - Sets the denomination of the currency (defaults to :default currency for the locale or "dollar" if not set).
    # * <tt>:connector</tt> - Sets the connector between integer part and decimal part of the currency (defaults to ", ").
    # * <tt>:format</tt> - Sets the format for non-negative numbers (defaults to "%n").
    # Field is <tt>%n</tt> for the currency amount in words.
    # * <tt>:negative_format</tt> - Sets the format for negative numbers (defaults to prepending "minus" to the number in words).
    # Field is <tt>%n</tt> for the currency amount in words (same as format).
    #
    # ==== Examples
    # [<tt>number_to_currency_in_words(123456.50)</tt>] 
    #   \=> one hundred and twenty-three thousand four hundred and fifty-six dollars, fifty cents
    # [<tt>number_to_currency_in_words(123456.50, :connector => ' and ')</tt>]
    #   \=> one hundred and twenty-three thousand four hundred and fifty-six dollars and fifty cents
    # [<tt>number_to_currency_in_words(123456.50, :locale => :fr, :connector => ' et ')</tt>] 
    #   \=> cent vingt-trois mille quatre cent cinquante-six dollars et cinquante cents
    # [<tt>number_to_currency_in_words(80300.80, :locale => :fr, :currency => :euro, :connector => ' et ')</tt>]
    #   \=> quatre-vingt mille trois cents euros et quatre-vingts centimes
    #
    # === Options only available for :en locale
    # * <tt>:delimiter</tt> - Sets the thousands delimiter (defaults to false).
    # * <tt>:skip_and</tt> - Skips the 'and' part in number - US (defaults to false).
    #
    # ==== Examples
    # [<tt>number_to_currency_in_words(201201201.201, :delimiter => true)</tt>] 
    #   \=> two hundred and one million, two hundred and one thousand, two hundred and one dollars, twenty cents
    # [<tt>number_to_currency_in_words(201201201.201, :delimiter => true, :skip_and => true)</tt>]
    #   \=> two hundred one million, two hundred one thousand, two hundred one dollars, twenty cents
    def number_to_currency_in_words number, options = {}

      options.symbolize_keys!

      currency_in_words = I18n.translate(:'number.currency_in_words', :locale => options[:locale], :default => {})

      defaults = DEFAULT_CURRENCY_IN_WORDS_VALUES.merge(currency_in_words)

      options  = defaults.merge!(options) 

      unless options[:currencies].has_key?(:default)
        options[:currencies].merge!(DEFAULT_CURRENCY_IN_WORDS_VALUES[:currencies])
      end

      format     = options.delete(:format)
      currency   = options.delete(:currency)
      currencies = options.delete(:currencies)
      options[:currency]  = currency && currencies.has_key?(currency) ? currencies[currency] : currencies[:default]
      options[:locale]  ||= I18n.default_locale

      if number.to_f < 0
        format = options.delete(:negative_format)
        number = number.respond_to?("abs") ? number.abs : number.sub(/^-/, '')
      end

      options_precision = {
        :precision => 2,
        :delimiter => '',
        :significant => false,
        :strip_insignificant_zeros => false,
        :separator => '.',
        :raise => true
      }

      begin
        rounded_number = number_with_precision(number, options_precision)
      rescue ActionView::Helpers::NumberHelper::InvalidNumberError => e
        if options[:raise]
          raise
        else
          rounded_number = format.gsub(/%n/, e.number)
          return e.number.to_s.html_safe? ? rounded_number.html_safe : rounded_number
        end
      end

      begin
        klass = "CurrencyInWords::#{options[:locale].to_s.capitalize}Texterizer".constantize
      rescue NameError
        if options[:raise]
          raise NameError, "Implement a class #{options[:locale].to_s.capitalize}Texterizer to support this locale, please."
        else
          klass = EnTexterizer
        end
      end

      number_parts = rounded_number.split(options_precision[:separator]).map(&:to_i)
      texterizer = CurrencyInWords::Texterizer.new(klass.new, number_parts, options)
      texterized_number = texterizer.texterize
      format.gsub(/%n/, texterized_number).html_safe
    end
  end

  #### 
  # :nodoc: all
  # This is the context class for texterizers
  class Texterizer
    attr_reader :number_parts, :options, :texterizer

    def initialize texterizer, splitted_number, options = {}
      @texterizer   = texterizer
      @number_parts = splitted_number
      @options      = options
    end

    def texterize
      if @texterizer.respond_to?('texterize')
        texterized_number = @texterizer.texterize self
        if texterized_number.is_a?(String)
          return texterized_number
        else
          raise TypeError, "a texterizer must return a String" if @options[:raise]
        end
      else
        raise NoMethodError, "a texterizer must provide a 'texterize' method" if @options[:raise]
      end
      # Fallback on EnTexterizer
      unless @texterizer.instance_of?(EnTexterizer)
        @texterizer = EnTexterizer.new
        self.texterize
      else
        raise RuntimeError, "you should use the option ':raise => true' to see what goes wrong"
      end
    end
  end

  #### 
  # :nodoc: all
  # This is the strategy class for English language
  class EnTexterizer

    def texterize context
      int_part, dec_part = context.number_parts
      connector          = context.options[:connector]
      int_unit_one       = context.options[:currency][:unit][:one]
      int_unit_many      = context.options[:currency][:unit][:many]
      dec_unit_one       = context.options[:currency][:decimal][:one]
      dec_unit_many      = context.options[:currency][:decimal][:many]
      @skip_and          = context.options[:skip_and]  || false
      @delimiter         = context.options[:delimiter] || false

      unless int_unit_many
        int_unit_many = int_unit_one+'s'
      end
      unless dec_unit_many
        dec_unit_many = dec_unit_one+'s'
      end

      int_unit = int_part > 1 ? int_unit_many : int_unit_one
      dec_unit = dec_part > 1 ? dec_unit_many : dec_unit_one

      texterized_int_part = (texterize_by_group(int_part).compact << int_unit).flatten.join(' ')
      texterized_dec_part = (texterize_by_group(dec_part).compact << dec_unit).flatten.join(' ')

      if dec_part.zero?
        texterized_int_part
      else
        texterized_int_part << connector << texterized_dec_part
      end
    end
    
    private
    
    # :nodoc: all
    A = %w(zero one two three four five six seven eight nine)
    B = %w(ten eleven twelve thirteen fourteen fifteen sixteen
           seventeen eighteen nineteen)
    C = [nil,nil,'twenty','thirty','forty','fifty','sixty','seventy',
         'eighty','ninety']
    D = [nil,'thousand','million','billion','trillion','quadrillion',
         'quintillion','sextillion','septillion','octillion']

    def texterize_by_group number, group=0
      return [under_100(number)] if number.zero?
      q,r = number.divmod 1000
      arr = texterize_by_group(q, group+1) if q > 0
      if r.zero?
        arr.last.chop! if group.zero? && @delimiter && arr.last.respond_to?('chop!')
        arr
      else
        arr = arr.to_a
        unless group.zero?
          arr << under_1000(r)
          arr << D[group] + (',' if @delimiter).to_s
        else
          arr.last.chop!  if @delimiter && r < 100 && arr.last.respond_to?('chop!')
          arr << 'and'    if !@skip_and && q > 0 && r < 100
          arr << under_1000(r)
        end
      end
    end
    
    def under_1000 number
      q,r = number.divmod 100
      arr = ([A[q]] << 'hundred' + (' and' unless @skip_and || r.zero?).to_s) if q > 0
      r.zero? ? arr : arr.to_a << under_100(r)
    end
  
    def under_100 number
      case number
      when 0..9   then A[number]
      when 10..19 then B[number - 10]
      else
        q,r = number.divmod 10
        C[q] + ('-' + A[r] unless r.zero?).to_s
      end
    end
  end

  #### 
  # :nodoc: all
  # This is the strategy class for French language
  class FrTexterizer
    
    def texterize context
      int_part, dec_part = context.number_parts
      connector          = context.options[:connector]
      int_unit_one       = context.options[:currency][:unit][:one]
      int_unit_many      = context.options[:currency][:unit][:many]
      int_unit_more      = context.options[:currency][:unit][:more]
      dec_unit_one       = context.options[:currency][:decimal][:one]
      dec_unit_many      = context.options[:currency][:decimal][:many]

      unless int_unit_many
        int_unit_many = int_unit_one+'s'
      end
      unless int_unit_more
        int_unit_more = if int_unit_many.start_with?("a","e","i","o","u")
                          "d'"+int_unit_many
                        else
                          "de "+int_unit_many
                        end
      end
      unless dec_unit_many
        dec_unit_many = dec_unit_one+'s'
      end

      int_unit = if int_part > 1
                   (int_part % 10**6).zero? ? int_unit_more : int_unit_many
                 else
                   int_unit_one
                 end
      dec_unit = dec_part > 1 ? dec_unit_many : dec_unit_one

      feminize = context.options[:currency][:unit][:feminine] || false
      texterized_int_part = (texterize_by_group(int_part, 0, feminize).compact << int_unit).flatten.join(' ')

      feminize = context.options[:currency][:decimal][:feminine] || false
      texterized_dec_part = (texterize_by_group(dec_part, 0, feminize).compact << dec_unit).flatten.join(' ')

      if dec_part.zero?
        texterized_int_part
      else
        texterized_int_part << connector << texterized_dec_part
      end
    end
   
    private

    # :nodoc: all
    A = %w(z&eacute;ro un deux trois quatre cinq six sept huit neuf)
    B = %w(dix onze douze treize quatorze quinze seize dix-sept dix-huit dix-neuf)
    C = [nil,nil,'vingt','trente','quarante','cinquante', 
         'soixante','soixante','quatre-vingt','quatre-vingt']
    D = [nil,'mille','million','milliard','billion','billiard','trillion','trilliard',
         'quadrillion','quadrilliard']

    def texterize_by_group number, group, feminine
      return [under_100(number, 0, feminine)] if number.zero?
      q,r = number.divmod 1000
      arr = texterize_by_group(q, group+1, feminine) if q > 0
      if r.zero?
        arr
      else
        arr = arr.to_a 
        arr << under_1000(r, group, feminine) 
        group.zero? ? arr : arr << (D[group] + ('s' if r > 1 && group != 1).to_s)
      end
    end
    
    def under_1000 number, group, feminine
      q,r = number.divmod 100
      arr = (q > 1 ? [A[q]] : []) << (r == 0 && q > 1 && group != 1 ? 'cents' : 'cent') if q > 0
      r.zero? ? arr : (r == 1 && q == 0 && group == 1 ? nil : arr.to_a << under_100(r, group, feminine))
    end

    def under_100 number, group, feminine
      feminine = (feminine and group.zero?)
      case number
      when 0..9   then A[number] + ('e' if feminine && number == 1).to_s
      when 10..19 then B[number - 10]
      else
        q,r = number.divmod 10
        case r
        when 1
          case q
          when 7 then C[q] + ('-et-' + B[r]).to_s
          when 8 then C[q] + ('-'    + A[r]).to_s + ('e' if feminine).to_s
          when 9 then C[q] + ('-'    + B[r]).to_s
          else        C[q] + ('-et-' + A[r]).to_s + ('e' if feminine).to_s
          end
        else
          if [7,9].include?(q)
            C[q] + ('-' + B[r]).to_s
          else
            C[q] + ('-' + A[r] if not r.zero?).to_s + ('s' if number == 80 && group != 1).to_s
          end
        end
      end
    end
  end
end
