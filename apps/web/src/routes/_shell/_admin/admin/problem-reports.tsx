import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/page';

/** Problem reports, where the Instance Administrator reads what Users reported from the Player. Empty for now. */
export const Route = createFileRoute('/_shell/_admin/admin/problem-reports')({
  component: ProblemReports,
});

function ProblemReports() {
  const {t} = useTranslation('web');
  return <Page title={t($ => $.web.problemReports.title)} />;
}
