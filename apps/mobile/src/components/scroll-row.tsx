import {type ReactNode, useRef, useState} from 'react';
import {ScrollView, type ScrollViewProps, View} from 'react-native';

/**
 * A row of items that scrolls sideways, without a scrollbar, on the screen's background. Each edge
 * fades while there's more to scroll that way, as on the web app.
 */
export function ScrollRow({
  children,
  ...props
}: Omit<ScrollViewProps, 'horizontal' | 'onScroll' | 'onLayout' | 'onContentSizeChange'> & {
  children: ReactNode;
}) {
  // The sizes stay out of the state, so the row only draws again when it reaches or leaves an edge
  const sizes = useRef({offset: 0, rowWidth: 0, contentWidth: 0});
  const [isAtStart, setIsAtStart] = useState(true);
  const [isAtEnd, setIsAtEnd] = useState(true);
  const update = (changes: Partial<typeof sizes.current>) => {
    sizes.current = {...sizes.current, ...changes};
    const {offset, rowWidth, contentWidth} = sizes.current;
    // A point's leeway, as rows scroll by fractions of a point
    setIsAtStart(offset <= 1);
    setIsAtEnd(offset + rowWidth >= contentWidth - 1);
  };

  return (
    <View>
      <ScrollView
        {...props}
        horizontal
        showsHorizontalScrollIndicator={false}
        scrollEventThrottle={16}
        onScroll={event => {
          update({offset: event.nativeEvent.contentOffset.x});
        }}
        onLayout={event => {
          update({rowWidth: event.nativeEvent.layout.width});
        }}
        onContentSizeChange={contentWidth => {
          update({contentWidth});
        }}
      >
        {children}
      </ScrollView>
      {!isAtStart && (
        <View className="pointer-events-none absolute inset-y-0 left-0 w-16 bg-linear-to-r from-background to-background/0" />
      )}
      {!isAtEnd && (
        <View className="pointer-events-none absolute inset-y-0 right-0 w-16 bg-linear-to-l from-background to-background/0" />
      )}
    </View>
  );
}
