# Refactoring Plan for `community_notice_card.dart`

The current `community_notice_card.dart` file is very large (2704 lines) and contains multiple distinct components that can be separated into their own files for better maintainability and organization.

## Identified Components

1. **CommentsPage** (lines 21-724): A page for displaying and managing comments on a community notice.
2. **_CommentItem** (lines 727-1046): A widget for displaying a single comment with its replies.
3. **VideoPlayerWidget** (lines 1049-1167): A widget for playing videos.
4. **PollWidget** (lines 1169-1776): A widget for displaying and interacting with polls.
5. **AttachmentWidget** (lines 1778-2041): A widget for displaying and handling file attachments.
6. **CommunityNoticeCard** (lines 2043-2703): The main widget for displaying a community notice.

## Proposed File Structure

```
lib/
├── widgets/
│   ├── community_notice/
│   │   ├── comments_page.dart
│   │   ├── comment_item.dart
│   │   ├── video_player_widget.dart
│   │   ├── poll_widget.dart
│   │   ├── attachment_widget.dart
│   │   └── community_notice_card.dart
│   └── community_notice_card.dart (main export file)
```

## Refactoring Steps

1. Create a new directory `lib/widgets/community_notice/` to house all the components.
2. Extract each component into its own file:
   - `comments_page.dart`: Move the `CommentsPage` class and its state.
   - `comment_item.dart`: Move the `_CommentItem` class.
   - `video_player_widget.dart`: Move the `VideoPlayerWidget` class and its state.
   - `poll_widget.dart`: Move the `PollWidget` class and its state.
   - `attachment_widget.dart`: Move the `AttachmentWidget` class and its state.
   - `community_notice_card.dart`: Move the `CommunityNoticeCard` class.

3. Create a main export file at `lib/widgets/community_notice_card.dart` that re-exports the `CommunityNoticeCard` class for backward compatibility.

## Implementation Details

### 1. Create the directory structure
```bash
mkdir -p lib/widgets/community_notice
```

### 2. Extract each component
For each component, create a new file with the appropriate imports and move the class definition.

### 3. Update imports
Update imports in each file to reference the new file locations.

### 4. Create the main export file
Create `lib/widgets/community_notice_card.dart` that exports the `CommunityNoticeCard` class from its new location.

## Benefits of Refactoring

1. **Improved Maintainability**: Smaller files are easier to understand and modify.
2. **Better Organization**: Related components are grouped together.
3. **Easier Navigation**: Developers can quickly find the specific component they need to work on.
4. **Reduced Merge Conflicts**: Smaller files reduce the chance of merge conflicts when multiple developers work on the codebase.
5. **Better Testability**: Isolated components are easier to test.

## Potential Challenges

1. **Circular Dependencies**: Need to be careful about circular import dependencies.
2. **Private Classes**: The `_CommentItem` class is private, so it needs to be made public or kept in the same file as its consumer.
3. **Shared State**: Some components might share state, which needs to be handled carefully.

This refactoring will not change any functionality but will make the codebase more maintainable and easier to work with.
