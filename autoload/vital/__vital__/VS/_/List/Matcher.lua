local alpha = {}
string.gsub('abcdefghijklmnopqrstuvwxyz', '.', function(char)
  alpha[string.byte(char)] = true
end)

local ALPHA = {}
string.gsub('ABCDEFGHIJKLMNOPQRSTUVWXYZ', '.', function(char)
  ALPHA[string.byte(char)] = true
end)

local digit = {}
string.gsub('1234567890', '.', function(char)
  ALPHA[string.byte(char)] = true
end)

local Matcher = {}

Matcher.WORD_BOUNDALY_ORDER_FACTOR = 5

--- match
Matcher.match = function(items, query, key)
  -- filter
  local matches = {}
  for i, item in ipairs(items) do
    local word = item[key]
    if #query > 0 then
      if item.filter_text and #item.filter_text > 0 then
        if Matcher.match_char(string.byte(query, 1), string.byte(item.filter_text, 1)) then
          word = item.filter_text
        end
      end
    end

    item.index = i
    item.score = 0
    item.fuzzy = false
    if #word >= #query then
      local score, fuzzy = Matcher.score(query, word)
      item.score = score
      item.fuzzy = fuzzy
      if item.score >= 1 or #query == 0 then
        table.insert(matches, item)
      end
    end
  end

  table.sort(matches, function(item1, item2)
    return item1.score > item2.score
  end)

  return matches
end

--- score
--
-- ### The score
--
--   The `score` is `matched char count` generally.
--
--   But compe will fix the score with some of the below points so the actual score is not `matched char count`.
--
--   1. Word boundarly order
--
--     compe prefers the match that near by word-beggining.
--
--   2. Strict case
--
--     compe prefers strict match than ignorecase match.
--
--
-- ### Matching specs.
--
--   1. Prefix matching per word boundaly
--
--     `bora`         -> `border-radius` # imaginary score: 4
--      ^^~~              ^^     ~~
--
--   2. Try sequencial match first
--
--     `woroff`       -> `word_offset`   # imaginary score: 6
--      ^^^~~~            ^^^  ~~~
--
--     * The `woroff`'s second `o` should not match `word_offset`'s first `o`
--
--   3. Prefer early word boundaly
--
--     `call`         -> `call`          # imaginary score: 4.1
--      ^^^^              ^^^^
--     `call`         -> `condition_all` # imaginary score: 4
--      ^~~~              ^         ~~~
--
--   4. Prefer strict match
--
--     `Buffer`       -> `Buffer`        # imaginary score: 6.1
--      ^^^^^^            ^^^^^^
--     `buffer`       -> `Buffer`        # imaginary score: 6
--      ^^^^^^            ^^^^^^
--
--   5. Use remaining char for fuzzy match
--
--     `fmofy`        -> `fnamemodify`   # imaginary score: 1
--      ^~~~~             ^    ~~  ~~
--
--   6. Avoid unexpected match detection
--
--     `candlesingle` -> candle#accept#single
--      ^^^^^^~~~~~~     ^^^^^^        ~~~~~~
--
--      * The `accept`'s `a` should not match to `candle`'s `a`
--
Matcher.score = function(query, word)
  -- Empty query
  if #query == 0 then
    return 1, false
  end

  -- Ignore if query is long than word
  if #query > #word then
    return 0, false
  end

  local query_bytes = { string.byte(query, 1, -1) }
  local word_bytes = { string.byte(word, 1, -1) }

  --- Gather matched regions
  local matches = {}
  local query_start_index = 0
  local query_end_index = 1
  local word_index = 1
  local word_bound_index = 1
  while query_end_index <= #query_bytes and word_index <= #word_bytes do
    local match = Matcher.find_match_region(query_bytes, query_start_index, query_end_index, word_bytes, word_index)
    if match and query_end_index <= match.query_match_end then
      match.index = word_bound_index
      query_start_index = match.query_match_start
      query_end_index = match.query_match_end + 1
      word_index = Matcher.get_next_semantic_index(word_bytes, match.word_match_end)
      table.insert(matches, match)
    else
      word_index = Matcher.get_next_semantic_index(word_bytes, word_index)
    end
    word_bound_index = word_bound_index + 1
  end

  if #matches == 0 then
    return 0, false
  end

  -- Compute prefix match score
  local score = 0
  local query_char_map = {}
  for _, match in ipairs(matches) do
    local s = 0
    for i = match.query_match_start, match.query_match_end do
      if not query_char_map[i] then
        s = s + 1
        query_char_map[i] = true
      end
    end
    if s > 0 then
      score = score + (s * ((1 + match.index) / #matches))
      score = score + (match.strict_match and 0.1 or 0)
    end
  end
  score = score - (#matches - 1)

  -- Check the word contains the remaining query. if not, it does not match.
  local last_match = matches[#matches]
  if last_match.query_match_end < #query_bytes then
    return 0, false
  end

  return score, false
end

--- find_match_region
Matcher.find_match_region = function(query_bytes, query_start_index, query_end_index, word_bytes, word_index)
  -- Datermine query position ( woroff -> word_offset )
  while query_start_index < query_end_index do
    if Matcher.match_char(query_bytes[query_end_index], word_bytes[word_index]) then
      break
    end
    query_end_index = query_end_index - 1
  end

  -- Can't datermine query position
  if query_start_index == query_end_index then
    return nil
  end

  local strict_match_count = 0
  local query_match_start = -1
  local query_index = query_end_index
  local word_offset = 0
  while query_index <= #query_bytes and word_index + word_offset <= #word_bytes do
    if Matcher.match_char(query_bytes[query_index], word_bytes[word_index + word_offset]) then
      -- Match start.
      if query_match_start == -1 then
        query_match_start = query_index
      end

      -- Increase strict_match_count
      if query_bytes[query_index] == word_bytes[word_index + word_offset] then
        strict_match_count = strict_match_count + 1
      end

      word_offset = word_offset + 1
    elseif query_match_start ~= -1 then
      -- Match end (partial region)
      return {
        query_match_start = query_match_start;
        query_match_end = query_index - 1;
        word_match_start = word_index;
        word_match_end = word_index + word_offset - 1;
        strict_match = strict_match_count == query_index - query_match_start;
      }
    end
    query_index = query_index + 1
  end

  -- Match end (whole region)
  if query_match_start ~= -1 then
    return {
      query_match_start = query_match_start;
      query_match_end = query_index - 1;
      word_match_start = word_index;
      word_match_end = word_index + word_offset - 1;
      strict_match = strict_match_count == query_index - query_match_start;
    }
  end

  return nil
end

--- get_next_semantic_index
Matcher.get_next_semantic_index = function(bytes, current_index)
  for i = current_index + 1, #bytes do
    if Matcher.is_semantic_index(bytes, i) then
      return i
    end
  end
  return #bytes + 1
end

--- is_semantic_index
Matcher.is_semantic_index = function(bytes, index)
  if index <= 1 then
    return true
  end
  if not Matcher.is_upper(bytes[index - 1]) and Matcher.is_upper(bytes[index]) then
    return true
  end
  if not Matcher.is_alpha(bytes[index - 1]) and Matcher.is_alpha(bytes[index]) then
    return true
  end
  return false
end

Matcher.is_upper = function(byte)
  return ALPHA[byte]
end

Matcher.is_alpha = function(byte)
  return alpha[byte] or ALPHA[byte]
end

Matcher.is_alnum = function(byte)
  return Matcher.is_alpha(byte) or digit[byte]
end

Matcher.match_char = function(byte1, byte2)
  local diff = byte1 - byte2
  return diff == 0 or diff == 32 or diff == -32
end

return Matcher

