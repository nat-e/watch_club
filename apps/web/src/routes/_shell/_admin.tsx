import {createFileRoute, redirect} from '@tanstack/react-router';

/** The Instance Administrator's pages. Other Users go home. */
export const Route = createFileRoute('/_shell/_admin')({
  beforeLoad: ({context}) => {
    if (!context.user.is_instance_administrator) {
      throw redirect({to: '/'});
    }
  },
});
