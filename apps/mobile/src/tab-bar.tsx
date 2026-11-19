/**
 * The tab bar of signed-in Users, which a screen can hide to cover the whole screen, such as search.
 */
import {useFocusEffect} from 'expo-router';
import {createContext, use, useCallback} from 'react';

/** The function that hides the tab bar, or shows it again, which the tabs' layout provides */
export const TabBarContext = createContext<(hidden: boolean) => void>(() => undefined);

/** Hides the tab bar while the screen that calls it has focus. */
export function useHiddenTabBar() {
  const setTabBarHidden = use(TabBarContext);
  useFocusEffect(
    useCallback(() => {
      setTabBarHidden(true);
      return () => {
        setTabBarHidden(false);
      };
    }, [setTabBarHidden]),
  );
}
