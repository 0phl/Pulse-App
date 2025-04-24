import 'package:flutter/material.dart';

class CommentText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color mentionColor;

  const CommentText({
    Key? key,
    required this.text,
    this.style,
    this.mentionColor = const Color(0xFF00C49A),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Text processing begins here

    // Check if the text contains a mention
    if (!text.startsWith('@')) {
      return Text(text, style: style);
    }

    // For mentions, we need to handle usernames that might contain spaces
    // Let's try to find where the actual mention ends and the rest of the text begins

    // First, check if there's any text after the mention
    // We'll look for a pattern like "@Username text" or "@Username Username text"

    // Start by assuming the entire text is a mention (if no additional content)
    String mention = text;
    String restOfText = "";
    bool hasAdditionalText = false;

    // Try to find where the mention ends and the comment begins
    // This is tricky because usernames can contain spaces
    // Let's look for common patterns in the text

    // First, check for our special double-space delimiter
    // We added this in the _addComment method to help identify where the mention ends
    int doubleSpaceIndex = text.indexOf('  ');
    if (doubleSpaceIndex != -1) {
      // We found our delimiter, so we know exactly where the mention ends
      mention = text.substring(0, doubleSpaceIndex);

      // Special handling for admin mentions
      if (mention.startsWith('@Admin ')) {
        // Check if this is a full admin mention (e.g., "@Admin Ronan Admin")
        final mentionParts = mention.split(' ');
        if (mentionParts.length >= 3 && mentionParts.last == 'Admin') {
          // Get the text after the double space delimiter
          final afterDelimiter = text.substring(doubleSpaceIndex + 2);

          // This is the actual content of the reply
          restOfText = afterDelimiter;
        } else {
          // This might be a partial admin mention, check if the next word is "Admin"
          final afterDelimiter = text.substring(doubleSpaceIndex + 2);
          if (afterDelimiter.startsWith('Admin ')) {
            // Include "Admin" in the mention
            mention = '$mention Admin';
            // Skip "Admin" and the space after it
            restOfText = afterDelimiter.substring(6);
          } else {
            // Regular case, just skip both spaces in the delimiter
            restOfText = text.substring(doubleSpaceIndex + 2);
          }
        }
      } else {
        // Regular case, just skip both spaces in the delimiter
        restOfText = text.substring(doubleSpaceIndex + 2);
      }

      hasAdditionalText = restOfText.isNotEmpty;
    } else {
      // No delimiter found, use the old approach
      // Check if the text contains multiple spaces
      final List<int> spaceIndices = [];
      for (int i = 0; i < text.length; i++) {
        if (text[i] == ' ') {
          spaceIndices.add(i);
        }
      }

      // If we have at least one space
      if (spaceIndices.isNotEmpty) {
        // For now, let's try a simple approach - assume the mention is everything
        // up to the second or third space (depending on the username format)

        // If we have at least 3 spaces, assume the mention ends at the second space
        // This handles cases like "@First Last rest of comment"
        if (spaceIndices.length >= 3) {
          // Check if this might be a reply to an admin (which has a special format)
          if (text.startsWith('@Admin ')) {
            // For admin mentions, we need to handle the format "@Admin First Last"
            // Check if the third word is "Admin" (as in "@Admin Ronan Admin")
            String thirdWord = "";
            if (spaceIndices.length > 2) {
              thirdWord = text.substring(spaceIndices[1] + 1, spaceIndices[2]);
            }

            if (thirdWord == "Admin") {
              // This is an admin mention with the format "@Admin Name Admin"
              mention = text.substring(0, spaceIndices[2] + 5); // Include "Admin" word

              // Check if there's text after the admin mention
              if (spaceIndices.length > 3) {
                restOfText = text.substring(spaceIndices[2] + 6); // Skip "Admin" word and space
              } else {
                // No additional text after the admin mention
                restOfText = "";
              }
            } else {
              // Regular admin mention without the trailing "Admin"
              mention = text.substring(0, spaceIndices[1]);
              restOfText = text.substring(spaceIndices[1] + 1);
            }
          } else {
            // Regular three-word mention
            mention = text.substring(0, spaceIndices[2]);
            restOfText = text.substring(spaceIndices[2] + 1);
          }
          hasAdditionalText = restOfText.isNotEmpty;
        }
        // If we have 2 spaces, check if this is a reply to a username with a space
        else if (spaceIndices.length == 2) {
          mention = text.substring(0, spaceIndices[1]);
          restOfText = text.substring(spaceIndices[1] + 1);
          hasAdditionalText = restOfText.isNotEmpty;
        }
        // If we have just 1 space, it could be "@Username text"
        else {
          mention = text.substring(0, spaceIndices[0]);
          restOfText = text.substring(spaceIndices[0] + 1);
          hasAdditionalText = restOfText.isNotEmpty;
        }
      }
    }

    // Process the extracted mention and text

    // If there's no additional text, just show the mention
    if (!hasAdditionalText) {
      // Get the default text style from the context
      final defaultStyle = DefaultTextStyle.of(context).style;

      // Apply styling for the mention

      // Special handling for mentions
      Color textColor = mentionColor;
      if (text.startsWith('@Admin ')) {
        // Use green color for admin mentions
        textColor = const Color(0xFF00C49A);

      } else if (text.startsWith('@')) {
        // Use blue color for user mentions (even in admin comments)
        textColor = Colors.blue[700]!;

      }

      return Text(
        text,
        style: (style ?? defaultStyle).copyWith(
          color: textColor,
          fontWeight: FontWeight.w600
        ),
      );
    }

    // Create a rich text with different styles
    // Get the default text style from the context
    final defaultStyle = DefaultTextStyle.of(context).style;

    // Apply styling for mentions in rich text

    // Special handling for mentions
    Color mentionTextColor = mentionColor;
    if (mention.startsWith('@Admin ')) {
      // Use green color for admin mentions
      mentionTextColor = const Color(0xFF00C49A);

    } else if (mention.startsWith('@')) {
      // Use blue color for user mentions (even in admin comments)
      mentionTextColor = Colors.blue[700]!;

    }

    // Use a Text.rich widget instead of RichText to ensure proper style inheritance
    // Check if the rest of the text contains any mentions
    List<TextSpan> textSpans = [];

    // First add the mention
    textSpans.add(
      TextSpan(
        text: mention,
        style: TextStyle(
          color: mentionTextColor,
          fontWeight: FontWeight.w600,
        ),
      )
    );

    // Add a space
    textSpans.add(const TextSpan(text: " "));

    // Check if the rest of the text contains any mentions
    if (restOfText.contains('@')) {
      // Split the text by spaces to find mentions
      final words = restOfText.split(' ');
      for (int i = 0; i < words.length; i++) {
        final word = words[i];
        if (word.startsWith('@')) {
          // This is a mention
          Color wordColor = Colors.blue[700]!;
          if (word.startsWith('@Admin')) {
            // Admin mention
            wordColor = const Color(0xFF00C49A);
          }

          textSpans.add(
            TextSpan(
              text: word,
              style: TextStyle(
                color: wordColor,
                fontWeight: FontWeight.w600,
              ),
            )
          );
        } else {
          // Regular word
          textSpans.add(TextSpan(text: word));
        }

        // Add a space after each word except the last one
        if (i < words.length - 1) {
          textSpans.add(const TextSpan(text: " "));
        }
      }
    } else {
      // No mentions in the rest of the text, just add it as is
      textSpans.add(TextSpan(text: restOfText));
    }

    return Text.rich(
      TextSpan(
        style: style ?? defaultStyle, // Base style for the entire text
        children: textSpans,
      ),
    );
  }
}
